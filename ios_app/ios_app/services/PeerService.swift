import Foundation
import Combine

// TODO we also have p2pservice now: isn't it the same thing? merge?
protocol PeerService {
    // peer == nil -> out of range (which includes peer has ble off)
    var peer: AnyPublisher<Peer?, Never> { get }
}

// Higher values -> slower UI updates
private let bleMeasurementsChunkSize = 5

class PeerServiceImpl: PeerService {
    let peer: AnyPublisher<Peer?, Never>

    private let nearby: Nearby
    private let bleManager: BleManager
    private let bleIdService: BleIdService

    init(nearby: Nearby, bleManager: BleManager, bleIdService: BleIdService) {
        self.nearby = nearby
        self.bleManager = bleManager
        self.bleIdService = bleIdService

        let validatedBlePeer = bleManager.discovered
            .filter { bleIdService.validate(bleId: $0.id) }

        // TODO handling of invalid peer
        // note validated means: they're exposing data in our service and characteristic uuid
        // if serv/char uuid are not variable, this can mean anyone using our app
        // if they're per-session, it means intentional impostor or some sort of error (?)
        // TODO think: should the signed data be the session id?
        // if serv/char uuid not variable, this would allow us to identify the session
        // but: other people can see if 2 people are meeting
        // if serv/char variable, it would still help somewhat but also not ideal privacy
        // best priv is variable serv/char + asymmetric encrypted data (peers offer different payload)
        // TODO review whetehr this privacy level is needed at this stage

        let blePeer: AnyPublisher<Peer, Never> = validatedBlePeer
            // Split the stream in chunks
            .scan([]) { acc, participant -> [BleParticipant] in
                if acc.count < bleMeasurementsChunkSize {
                    return acc + [participant]
                } else {
                    return [] // Start new chunk
                }
            }
            // Calculate average for each chunk
            .compactMap { chunk -> BleParticipant? in
                if chunk.count == bleMeasurementsChunkSize {
                    return chunk.filterAndAverageDistance()
                } else {
                    // Discard intermediate results emitted by scan. We only want complete chunks.
                    return nil
                }
            }
            .map { blePeer in
                // TODO generate peer's name when creating/joining session, allow user to override (the peer)
                Peer(name: "TODO BLE peer name",
                     dist: Float(blePeer.distance),
                     loc: nil,
                     dir: nil,
                     src: .ble
                )
            }
            .handleEvents(receiveOutput: { peer in
                log.d("Updated peer: \(peer)", .ble)
            })
            .share()
            .eraseToAnyPublisher()

        // TODO: Nearby distance unit unclear. 
        let nearbyPeer: AnyPublisher<Peer, Never> = nearby.discovered
            .map { nearbyObj in
                Peer(name: nearbyObj.name,
                     dist: nearbyObj.dist,
                     loc: nearbyObj.loc,
                     dir: nearbyObj.dir.map { Direction(x: $0.x, y: $0.y) },
                     src: .nearby
                )
            }
            .handleEvents(receiveOutput: { peer in
                log.d("Updated peers: \(peer)", .nearby)
            })
            .share()
            .eraseToAnyPublisher()

        let peerFilter: AnyPublisher<PeerSource, Never> = nearbyPeer.combineLatest(nearby.sessionState.removeDuplicates())
            .map { peer, sessionState in
                // Note: if nearby doesn't provide distance intermittently while in range,
                // the back and forth with ble (?? false) will not look good
                // there will be definitely intermittency in the outer edges of the nearby range.
                // we could implement something to keep the last peer source until the new one stabilizes
                // (last x events in a row came from source y)
                // TODO when testing with devices, check actual nearby range. 100 is a placeholder.
                let inNearbyRange = peer.dist.map { $0 < 100 } ?? false
                if sessionState == .active && inNearbyRange {
                    return .nearby
                } else {
                    return .ble
                }
            }
            .prepend(.ble)
            .eraseToAnyPublisher()

        peer = blePeer
            .merge(with: nearbyPeer)
            .combineLatest(peerFilter)
            .filter { peer, filter in
//                log.v("Filtering peer: \(peer) with: \(filter)", .ble, .nearby, .peer)
                peer.src == filter
            }
            .map { peer, _ in peer }
            .prepend(nil) // start with peer == nil, meaning out of range
            .eraseToAnyPublisher()
    }
}

private extension Array where Element == BleParticipant {

    // Removes abnormal distance jumps and averages the normal values
    func filterAndAverageDistance() -> Element? {
        // we need one element to retrieve the id
        // (NOTE: assumes all measurements come from same peer, which should be always the case since we support only 1 peer)
        // Also, prevents division by 0 when dividing by count
        guard let first = self.first else { return nil }

        // sort by distance in ascending order
        let sortedArray = sorted { $0.distance < $1.distance }

        // The delta between each pair of distances, used to filter out abnormal jumps
        let distanceDeltas = sortedArray.reduce(([], -1)) { acc, bleParticipant -> ([Double], Double) in
            if acc.1 == -1 {
                // first element (disance has default value -1): no previous element, so
                // no distance (just pass through empty array)
                return (acc.0, bleParticipant.distance)
            } else {
                return (acc.0 + [bleParticipant.distance - acc.1], bleParticipant.distance)
            }
        }

        // Filter abnormal jumps: rssi fluctuates a lot and we often get measurements 1-2 (sometimes 10+) meters appart,
        // while not even moving the devices (note: measured iOS - iOS).
        // If there are edge cases where one of such jumps represent reality, it's not an issue discarding it,
        // since we'll get the change in the next batch
        var measurementsToAverage: [BleParticipant]
        if let outsiderIndex = distanceDeltas.0.firstIndex(where: { $0 > 1 }) {
            measurementsToAverage = Array(sortedArray[0...outsiderIndex])
        } else {
            measurementsToAverage = sortedArray
        }

        // Compute an average for the current batch (without the jumps)
        let average = measurementsToAverage.reduce(0) { acc, participant in
            acc + participant.distance
        } / Double(self.count) // division by 0 impossible: we've a "first" guard

        return BleParticipant(id: first.id, distance: average)
    }
}

extension Array {
    func chunked(by chunkSize: Int) -> [[Element]] {
        stride(from: 0, to: count, by: chunkSize).map {
            Array(self[$0 ..< Swift.min($0 + chunkSize, count)])
        }
    }
}
