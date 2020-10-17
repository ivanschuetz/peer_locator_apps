import Foundation
import Combine

/**
 * Triggers validation request each x secs
 */
protocol PeerValidationActivator {
    func activate()
    func deactivate()
}

class PeerValidationActivatorImpl: PeerValidationActivator {
    private let bleValidation: BleValidation

    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init(bleValidation: BleValidation, sessionIsReady: SessionIsReady) {
        self.bleValidation = bleValidation

        sessionIsReady.isReady
            .sink { [weak self] ready in
                if ready {
                    // TODO does this work after e.g. restarting the app (with an active meeting)?
                    // (assume yes, as "ready" status is persisted, so we get it at launch)
                    log.i("Session activated, starting peer validation", .ble)
                    self?.activate()
                } else {
                    // TODO(pmvp) maybe stop validation when peers are successfully exchanging data?
                    // the behavior re: what to do if the periodic validation fails after peers are exchanging data, is currently undefined. In the future we _need_ this validation, but then we'll also have a spec.
                    log.i("Session deactivated, stopping peer validation", .ble)
                    self?.deactivate()
                }
            }
            .store(in: &cancellables)
    }

    func activate() {
        startTimer()
    }

    func deactivate() {
        stopTimer()
    }

    private func startTimer() {
        stopTimer()

        DispatchQueue.main.async {
            self.timer = self.createTimer()
        }
    }

    private func createTimer() -> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            log.v("Timer tick: trying to validate peer...", .session)
            _ = self?.bleValidation.validatePeer()
        }
        // https://www.raywenderlich.com/113835-ios-timer-tutorial
        RunLoop.current.add(timer, forMode: .common)
        timer.tolerance = 1

        return timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
