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

    private func handleSessionResult(_ result: Result<Session?, ServicesError>) {
        switch result {
        case .success(let session):
            if let session = session {
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
            log.e("Critical: error retrieving session. Can't refresh state. Error: \(e)", .session)
            // TODO handling? stop timer and tell user to retry manually (how)? or re-create/join session? crash app?
            stopRefreshTimer()
            break
        }
    }

    private func startRefreshTimer() {
        // TODO use for all timers. Sometimes they don't start without this.
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
