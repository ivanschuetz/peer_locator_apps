import Foundation
import Combine
import SwiftUI

class ContentViewModel: ObservableObject {
    @Published var distance: String = ""
    @Published var directionAngle: Angle = Angle(radians: 0)

    private var peerCancellable: AnyCancellable?

    private let sessionDataDispatcher: SessionDataDispatcher

    init(sessionDataDispatcher: SessionDataDispatcher) {
        self.sessionDataDispatcher = sessionDataDispatcher
        peerCancellable = sessionDataDispatcher.peer.sink { [weak self] peer in
            let formattedDistance = peer.dist.flatMap { NumberFormatters.oneDecimal.string(from: $0) }
            // TODO(pmvp) is "?" ok for missing distance? when can this happen? should fallback to bluetooth
            // moving to pmvp: let's test first with other people to see if it happens.
            // we could fallback to ble distance, but that's probably not a good experience, as there would be
            // unexpected jumps. So "?" or similar may be fine.
            self?.distance = formattedDistance.map { "\($0)m" } ?? "?"
            if let dir = peer.dir {
                self?.directionAngle.radians = toAngle(dir: dir)
            }
        }
    }
}

private func toAngle(dir: Direction) -> Double {
    // "normal" formula to get angle from x, y (only for positive quadrant): atan(dir.y / dir.x)
    // additions:
    // atan needs adjustment for negative quadrants (x or y < 0)
    // + (Double.pi / 2): iOS coordinate system adjustment
    // -dir.y: iOS coordinate system adjustment
    let res = Double(atan(-dir.y / dir.x)) + (Double.pi / 2)
    if dir.x < 0 {
        return res + Double.pi
    } else if dir.y < 0 {
        return res + (Double.pi * 2)
    } else {
        return res
    }
}
