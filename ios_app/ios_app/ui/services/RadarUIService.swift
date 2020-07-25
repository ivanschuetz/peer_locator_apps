import Foundation
import UIKit
import Combine

//let maxRadius: CGFloat = 6000
// Nearby max radius with direction currently seems to be ~0.30m (simulator, of course)
// For distance so far no limits found with simulator: ~2.16m on screen's edges
let maxRadius: CGFloat = 30

let viewRadius: CGFloat = 150 // TODO: ensure same as in RadarView

protocol RadarUIService {
    var radar: AnyPublisher<[RadarItem], Never> { get }
}

class RadarUIServiceImpl: RadarUIService {
    let radar: AnyPublisher<[RadarItem], Never>

    private let peerService: PeerService

    private var radarCancellable: AnyCancellable?

    init(peerService: PeerService) {
        self.peerService = peerService

        radar = peerService.peers.map { peers in
            let viewItems = peers.compactMap { $0.toRadarItem() }
            return viewItems
        }.eraseToAnyPublisher()
    }
}

extension Peer {
    func toRadarItem() -> RadarItem? {
        // Items may not have direction / loc. Don't show radar items for these.
        guard
            let loc = loc,
            let dist = dist
        else { return  nil }

        let multiplier = viewRadius / maxRadius

        let screenLoc = CGPoint(
            x: CGFloat(loc.x) * multiplier + viewRadius,
            y: -CGFloat(loc.y) * multiplier + viewRadius
        )

        // Temporary: as we're using distance as coordinates
        let distance = String(format: "%.0f", dist)
        let screenDistance = String(format: "%.0f", screenLoc.x)

        return RadarItem(
            id: name,
            loc: screenLoc,
            text: "\(distance)->\(screenDistance)"
        )
    }
}

struct RadarItem: Identifiable, Hashable {
    var id: String
    let loc: CGPoint
    let text: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class RadarUIServiceNoop: RadarUIService {
    let radar: AnyPublisher<[RadarItem], Never> = Result.Publisher([]).eraseToAnyPublisher()
}
