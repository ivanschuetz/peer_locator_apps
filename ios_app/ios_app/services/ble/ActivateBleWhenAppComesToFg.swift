import Foundation
import Combine

protocol ActivateBleWhenAppComesToFg {
    func request()
}

/**
 * Tries to activate ble when the app comes to the fg.
 * If the device's ble is deactivated, nothing happens TODO confirm
 * The reason we do this, is because we don't want to force the user to enable ble when opening the app,
 * only when we clearly need ble.
 * Activating it always if it's enabled seems low cost (activating on demand and coordinating this with the enable
 * dialog seems a bit more complicated).
 */
class ActivateBleWhenAppComesToFgImpl: ActivateBleWhenAppComesToFg {
    private var eventsCancellable: AnyCancellable?

    private let requestSubject = CurrentValueSubject<Bool, Never>(false)

    init(appEvents: AppEvents, bleManager: BleManager) {
        eventsCancellable = appEvents.events
            .filter { $0 == .toFg }
            .withLatestFrom(requestSubject)
            .sink { [weak self] requested in
                // TODO what happens here exactly when ble isn't enabled? logs?
                if requested {
                    bleManager.start()
                    self?.requestSubject.send(false)
                }
            }
    }

    func request() {
        requestSubject.send(true)
    }
}
