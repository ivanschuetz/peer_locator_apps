import Foundation
import Combine
import SwiftUI

enum MeetingMainViewContent {
    case enableBle, connected
}

class MeetingViewModel: ObservableObject {
    @Published var distance: String = ""
    @Published var directionAngle: Angle = Angle(radians: 0)
    @Published var mainViewContent: MeetingMainViewContent = .connected

    private var discoveredCancellable: AnyCancellable?
    private var bleEnabledCancellable: AnyCancellable?

    private let sessionService: CurrentSessionService
    private let settingsShower: SettingsShower
    private let bleEnabledService: BleEnabledService

    init(peerService: PeerService, sessionService: CurrentSessionService,
         settingsShower: SettingsShower, bleEnabledService: BleEnabledService) {
        self.sessionService = sessionService
        self.settingsShower = settingsShower
        self.bleEnabledService = bleEnabledService

        discoveredCancellable = peerService.peer.sink { [weak self] peer in
            let formattedDistance = peer.dist.flatMap { NumberFormatters.oneDecimal.string(from: $0) }
            // TODO is "?" ok for missing distance? when can this happen? should fallback to bluetooth
            self?.distance = formattedDistance.map { "\($0)m" } ?? "?"
            if let dir = peer.dir {
                self?.directionAngle.radians = toAngle(dir: dir)
            }
        }

        bleEnabledCancellable = bleEnabledService.bleEnabled.sink { [weak self] enabled in
            self?.mainViewContent = enabled ? .connected : .enableBle
        }
    }

    func deleteSession() {
        sessionService.deleteSessionLocally()
    }

    func onSettingsButtonTap() {
        settingsShower.show()
    }

    func requestEnableBle() {
        bleEnabledService.enable()
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
