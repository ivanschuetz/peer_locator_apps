import Foundation
import Combine

protocol PeerService {
    var peers: AnyPublisher<Set<Peer>, Never> { get }
}

class PeerServiceImpl: PeerService {
    let peers: AnyPublisher<Set<Peer>, Never>

    private let nearby: Nearby

    init(nearby: Nearby) {
        self.nearby = nearby

        // TODO: Nearby distance unit unclear. 
        peers = nearby.discovered
            .map { nearbyObj in
                Peer(name: nearbyObj.name,
                     dist: nearbyObj.dist,
                     loc: nearbyObj.loc,
                     dir: nearbyObj.dir.map { Direction(x: $0.x, y: $0.y) }
                )
            }
            .scan(Dictionary<String, Peer>(), { acc, peer in
                var dict: Dictionary<String, Peer> = acc
                dict[peer.name] = peer

                return dict
            })
            .map { Set($0.values) }
            .handleEvents(receiveOutput: { peers in
                log.d("Updated peers: \(peers)", .nearby)
            })
            .eraseToAnyPublisher()
    }
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

struct Direction: Equatable {
    let x: Float
    let y: Float
}
