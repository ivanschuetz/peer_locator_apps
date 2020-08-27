import Foundation
import Combine
import SwiftUI

class MeetingViewModel: ObservableObject {
    @Published var distance: String = ""
    @Published var directionAngle: Angle = Angle(radians: 0)

    private var discoveredCancellable: AnyCancellable?

    init(peerService: PeerService) {
        discoveredCancellable = peerService.peer.sink { [weak self] peer in
            // TODO handle optional
            self?.distance = "\(peer.dist)m"
            if let dir = peer.dir {
                self?.directionAngle.radians = toAngle(dir: dir)
            }
        }
    }

}

struct BleIdRow: Identifiable {
    let id: UUID
    let bleId: BleId
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
