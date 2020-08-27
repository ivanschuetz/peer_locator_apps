import Foundation
import Combine

// TODO we also have p2pservice now: isn't it the same thing? merge?
protocol PeerService {
    var peer: AnyPublisher<Peer, Never> { get }
}

class PeerServiceImpl: PeerService {
    let peer: AnyPublisher<Peer, Never>

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

        // Temporary placeholder implementation: ble until the first nearby event detected,
        // after that always nearby.
        // TODO switch to ble on threshold (> x nearby events / second?) and back
        // and reduce intermittency somehow: ranges/tolerance?
        let peerFilter: AnyPublisher<PeerSource, Never> = nearbyPeer
            .map { _ in .nearby }
            .prepend(.ble)
            .eraseToAnyPublisher()

        peer = blePeer
            .merge(with: nearbyPeer)
            .combineLatest(peerFilter)
            .filter { peer, filter in
                log.v("Filtering peer: \(peer) with: \(filter)", .ble, .nearby, .peer)
                return peer.src == filter
            }
            .map { peer, _ in peer }
            .eraseToAnyPublisher()
    }
}

enum PeerSource {
    case ble, nearby
}

struct Location: Equatable {
    let x: Float
    let y: Float
}

struct Peer: Hashable {
    let name: String
    // TODO think about optional distance (and other field). if dist isn't set, should the point disappear or show
    // the last loc with a "stale" status? requires to clear: can dist disappear only when out of range?
    // Note that this applies only to Nearby. BLE dist (i.e. rssi) is maybe always set, but check this too.
    let dist: Float?
    let loc: Location?
    let dir: Direction?
    let src: PeerSource

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

struct Direction: Equatable {
    let x: Float
    let y: Float
}
