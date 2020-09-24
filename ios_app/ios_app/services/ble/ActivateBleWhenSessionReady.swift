import Foundation
import Combine

/**
 * Observes relevant events to start/stop the central and peripheral and validation process.
 * Note: Not related with enabling ble itself (this is done by BleEnabler)
 * TODO: the current implementation seems outdated. Review.
 * TODO: coordination with BleEnabler? E.g. if we detect that ble was enabled,
 * shouldn't we activate too?
 */

class ActivateBleWhenSessionReady {
    private var cancellables: Set<AnyCancellable> = []

    init(bleManager: BleManager, bleEnabler: BleEnabler, sessionIsReady: SessionIsReady) {
        sessionIsReady.isReady
            .sink { ready in
                if ready {
                    log.i("Session activated, starting ble", .ble)
                    bleEnabler.showEnableDialogIfDisabled()
                    bleManager.start()
                } else {
                    log.i("Session deactivated, stopping ble", .ble)
                    bleManager.stop()
                }
            }
            .store(in: &cancellables)
    }
}

private enum SessionStateChangeEvent {
    case wentOn, wentOff
}
