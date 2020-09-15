import Foundation
import Combine
import SwiftUI

enum MeetingMainViewContent {
    case enableBle, connected, unavailable
}

class MeetingViewModel: ObservableObject {
    @Published var distance: String = ""
    @Published var directionAngle: Angle = Angle(radians: 0)
    @Published var mainViewContent: MeetingMainViewContent = .connected

    private var peerCancellable: AnyCancellable?
    private var bleEnabledCancellable: AnyCancellable?

    private let sessionService: CurrentSessionService
    private let settingsShower: SettingsShower
    private let bleEnabledService: BleEnabledService

    init(peerService: DetectedPeerService, sessionService: CurrentSessionService,
         settingsShower: SettingsShower, bleEnabledService: BleEnabledService) {
        self.sessionService = sessionService
        self.settingsShower = settingsShower
        self.bleEnabledService = bleEnabledService

        peerCancellable = peerService.peer.sink { [weak self] peer in
            self?.handlePeer(peerMaybe: peer)
        }

        bleEnabledCancellable = bleEnabledService.bleEnabled.sink { [weak self] enabled in
            self?.mainViewContent = enabled ? .connected : .enableBle
        }
    }

    private func handlePeer(peerMaybe: DetectedPeer?) {
        if let peer = peerMaybe {
            let formattedDistance = peer.dist.flatMap { NumberFormatters.oneDecimal.string(from: $0) }
            // TODO is "?" ok for missing distance? when can this happen? should fallback to bluetooth
            distance = formattedDistance.map { "\($0)m" } ?? "?"
            if let dir = peer.dir {
                directionAngle.radians = toAngle(dir: dir)
            }
            mainViewContent = .connected
        } else {
            mainViewContent = .unavailable
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
