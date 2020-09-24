import Foundation
import Combine

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
                    log.i("Session activated, starting peer validation", .ble)
                    self?.activate()
                } else {
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
