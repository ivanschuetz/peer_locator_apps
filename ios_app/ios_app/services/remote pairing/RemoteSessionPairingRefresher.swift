import Foundation
import Combine

class RemoteSessionPairingRefresher {
    private let sessionManager: RemoteSessionManager

    private var cancellables: Set<AnyCancellable> = []

    private var refreshTimer: Timer?

    init(sessionService: CurrentSessionService, sessionManager: RemoteSessionManager) {
        self.sessionManager = sessionManager

        sessionService.session
            .compactMap{ sessionState in
                switch sessionState {
                case .result(let res): return res
                case .progress: return nil
                }
            }
            .removeDuplicates()
            .sink { [weak self] state in
                self?.handleSessionResult(state)
            }
            .store(in: &cancellables)
    }

    private func handleSessionResult(_ result: Result<SessionSet, ServicesError>) {
        switch result {
        case .success(let session):
            if let session = session.asNilable() {
                if !session.isReady {
                    log.d("There's a session and it's not ready. Refreshing...", .session)
                    startRefreshTimer()
                } else {
                    log.v("Session is ready. Stopping refresh timer.", .session)
                    stopRefreshTimer()
                }
            } else {
                log.v("No session. Stopping refresh timer, in case it was deleted.", .session)
                stopRefreshTimer()
            }
        case .failure(let e):
            // Note that we don't stop the timer. It could work the next time (e.g. if it's a server timeout error)
            // This could spam the logs for other kind of errors. TODO(pmvp) Revisit.
            log.e("Error retrieving session. Can't refresh state. Error: \(e)", .session)
            break
        }
    }

    private func startRefreshTimer() {
        // DispatchQueue.main.async needed sometimes (like here) when starting timer. Otherwise it just doesn't.
        // forgot to add StackOverflow link.
        DispatchQueue.main.async {
            if let timer = self.refreshTimer, timer.isValid {
                log.w("Suspicious? starting session refresh timer while there's one active already. Ignoring.", .ble)
                return
            }
            self.refreshTimer = self.createRefreshTimer()
        }
    }

    private func createRefreshTimer() -> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            log.v("Timer tick: refreshing session...", .session)
            _ = self?.sessionManager.refresh()
        }
        RunLoop.current.add(timer, forMode: .common)
        timer.tolerance = 1
        return timer
    }

    private func stopRefreshTimer() {
        log.d("Stopping session refresh timer", .session)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
