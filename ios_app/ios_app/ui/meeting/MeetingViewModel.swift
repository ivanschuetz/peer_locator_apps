import Foundation
import Combine
import SwiftUI

enum MeetingMainViewContent {
    case enableBle, connected, unavailable
}

class MeetingViewModel: ObservableObject {
    @Published var distance: String = ""
    @Published var directionAngle: Angle = Angle(radians: 0)
    @Published var isAccurate: Bool = false
    @Published var mainViewContent: MeetingMainViewContent = .connected
    @Published var showSettingsModal: Bool = false

    private var peerCancellable: AnyCancellable?

    private let sessionManager: RemoteSessionManager
    private let bleEnabler: BleEnabler

    init(peerService: DetectedPeerService, sessionManager: RemoteSessionManager, bleEnabler: BleEnabler,
         bleState: BleStateObservable) {
        self.sessionManager = sessionManager
        self.bleEnabler = bleEnabler

        peerCancellable = peerService.peer
            .combineLatest(bleState.bleEnabled)
            .removeDuplicates(by: { t1, t2 in
                t1 == t2
            })
            .sink { [weak self] peer, bleEnabled in
                self?.handlePeer(peerMaybe: peer, bleEnabled: bleEnabled)
            }
    }

    private func handlePeer(peerMaybe: DetectedPeer?, bleEnabled: Bool) {
        let content = mainViewContent(peerMaybe: peerMaybe, bleEnabled: bleEnabled)
        log.d("Main view content: \(content), is there peer: \(peerMaybe != nil), bleEnabled: \(bleEnabled)", .ui)
        mainViewContent = content
    }

    private func mainViewContent(peerMaybe: DetectedPeer?, bleEnabled: Bool) -> MeetingMainViewContent {
        guard bleEnabled else {
            return .enableBle
        }

        if let peer = peerMaybe {
            let formattedDistance = peer.dist.flatMap { NumberFormatters.oneDecimal.string(from: $0) }
            // TODO is "?" ok for missing distance? when can this happen? should fallback to bluetooth
            distance = formattedDistance.map { "\($0)m" } ?? "?"
            if let dir = peer.dir {
                directionAngle.radians = toAngle(dir: dir)
            }
            isAccurate = peer.dir != nil

            return .connected
        } else {
            return .unavailable
        }
    }

    func deleteSession() {
        _ = sessionManager.delete()
    }

    func onSettingsButtonTap() {
        showSettingsModal = true
    }

    func requestEnableBle() {
        bleEnabler.showEnableDialogIfDisabled()
    }

    deinit {
        log.d("View model deinit", .ui)
    }
}

struct BleIdRow: Identifiable {
    let id: UUID
    let bleId: BleId
}

// TODO(pmvp) use the toAngle() extension on Direction and adjust result for iOS coords
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
