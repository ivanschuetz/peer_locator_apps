import Foundation
import Combine

/**
 * Observes relevant events to start/stop the central and peripheral
 * Note: Not related with enabling ble itself (this is done by BleEnabler)
 * TODO: the current implementation seems outdated. Review.
 * TODO: coordination with BleEnabler? E.g. if we detect that ble was enabled,
 * shouldn't we activate too?
 */
protocol ActivateBleWhenSessionReady {}

class ActivateBleWhenSessionReadyImpl: ActivateBleWhenSessionReady {
    private var currentSessionCancellable: AnyCancellable?

    init(bleManager: BleManager, sessionService: CurrentSessionService, bleEnabler: BleEnabler) {
        currentSessionCancellable = sessionService.session
            .map({ sessionRes -> Bool in
                switch sessionRes {
                case .success(let session):
                    if let session = session {
                        return session.isReady
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
                case .wentOn:
                    log.i("Session activated, starting ble")
                    bleEnabler.showEnableDialogIfDisabled()
                    bleManager.start()
                case .wentOff:
                    log.i("Session deactivated, stopping ble")
                    bleManager.stop()
                }
            }
    }
}

private enum SessionStateChangeEvent {
    case wentOn, wentOff
}
