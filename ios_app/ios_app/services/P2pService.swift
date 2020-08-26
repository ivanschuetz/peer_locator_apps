import Foundation
import Combine

protocol P2pService {}

class P2pServiceImpl: P2pService {
    private let bleManager: BleManager

    private var currentSessionCancellable: AnyCancellable?

    init(bleManager: BleManager, sessionService: CurrentSessionService) {
        self.bleManager = bleManager

        currentSessionCancellable = sessionService.session
            .map({ sharedSessionRes -> Bool in
                switch sharedSessionRes {
                case .success(let session):
                    if let session = session {
                        return session.isReady == .yes
                    } else {
                        return false
                    }
                case .failure:
                    return false
                }
            })
            .removeDuplicates()
            // If we map to ready/not ready and remove duplicates, it means each event is a ready<->not ready change
            .map { isReady -> SessionStateChangeEvent in
                if isReady {
                    return .wentOn
                } else {
                    return .wentOff
                }
            }
            .sink { [weak self] stateChange in
                switch stateChange {
                case .wentOn: self?.activateSession()
                case .wentOff: self?.deactivateSession()
                }
            }
    }

    private func activateSession() {
        log.i("Session activated, starting ble")
        bleManager.start()
    }

    private func deactivateSession() {
        log.i("Session deactivated, stopping ble")
        bleManager.stop()
    }
}

private enum SessionStateChangeEvent {
    case wentOn, wentOff
}
