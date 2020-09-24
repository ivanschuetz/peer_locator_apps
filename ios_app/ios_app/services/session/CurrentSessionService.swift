import Combine

enum SessionState {
    case result(Result<Session?, ServicesError>)
    case progress
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
            uiNotifier.show(.error("Error deleting sesion: \(e)"))
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
