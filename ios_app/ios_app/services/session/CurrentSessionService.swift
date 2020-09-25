import Combine

enum SessionState: Equatable {
    case result(Result<Session?, ServicesError>)
    case progress

    static func == (lhs: SessionState, rhs: SessionState) -> Bool {
        switch (lhs, rhs) {
        case (.result(let res1), .result(let res2)):
            switch (res1, res2) {
            case (.success(let session1), .success(let session2)): return session1 == session2
            case (.failure(let e1), .failure(let e2)): return e1 == e2
            default: return false
            }
        case (.progress, progress): return true
        default: return false
        }
    }
}

/**
 * Manages current configured session.
 * If there's no session configured yet, the observable's session is nil.
 * Note that this class shows UI notifications for session's failure result,
 * so observers must not show UI notifications again for this.
 */
protocol CurrentSessionService {
    var session: AnyPublisher<SessionState, Never> { get }

    func setSessionState(_ state: SessionState)

    // Locally opposed to the automatic deletion in the backend after peers have exchanged data
    // Here the user isn't interested in the session anymore: the session data / keys / peers data are removed
    func deleteSessionLocally() -> Result<(), ServicesError>
}

class CurrentSessionServiceImpl: CurrentSessionService {
    private let sessionSubject: CurrentValueSubject<SessionState, Never>

    let session: AnyPublisher<SessionState, Never>

    private let localSessionManager: LocalSessionManager
    private let uiNotifier: UINotifier

    init(localSessionManager: LocalSessionManager, uiNotifier: UINotifier) {
        self.localSessionManager = localSessionManager
        self.uiNotifier = uiNotifier

        sessionSubject = CurrentValueSubject(.result(localSessionManager.getSession()))
        session = sessionSubject
            .handleEvents(receiveOutput: { session in
//                log.d("Current session was updated to: \(session)", .session)
                if case .result(.failure(let e)) = session {
                    log.e("Current session error: \(e)", .session)
                }
            })
            .eraseToAnyPublisher()
    }

    func setSessionState(_ state: SessionState) {
        // TODO warning says that we can publish changes only from main thread (use receive(on:))
        sessionSubject.send(state)
    }

    func deleteSessionLocally() -> Result<(), ServicesError> {
        let res = localSessionManager.clear()
        switch res {
        case .success:
            sessionSubject.send(.result(.success(nil)))
            uiNotifier.show(.success("Session deleted"))
        case .failure(let e):
            log.e("Couldn't delete session locally: \(e)")
            uiNotifier.show(.error("Couldn't delete session."))
        }
        return res
    }
}

class NoopCurrentSessionService: CurrentSessionService {
    var session: AnyPublisher<SessionState, Never> = Just(.result(.success(nil)))
        .eraseToAnyPublisher()

    func setSessionState(_ state: SessionState) {}
    func deleteSessionLocally() -> Result<(), ServicesError> { return .success(()) }
}
