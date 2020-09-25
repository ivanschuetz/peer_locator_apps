import Combine

enum SessionSet: Equatable {
    case isSet(Session)
    case notSet

    // Whether the session was just deleted. Note that this is a "memory-only" state. If we delete a session
    // and restart the app, the status will be .notSet.
    // Functionally, .deleted is a subset to .notSet. Use asNilable() if only interested in "is set" / "is not set"
    // .deleted is used only in special cases, where we want to know the cause of "not set",
    // like navigation: if the session was deleted, we navigate, if the
    // session is just nil, we don't navigate, as this can happen in several places where we don't want to
    // navigate. TODO revisit, feel that there's something in the navigation architecture that has to be improved.
    case deleted

    func asNilable() -> Session? {
        switch self {
        case .notSet, .deleted: return nil
        case .isSet(let session): return session
        }
    }

    static func fromNilable(_ session: Session?) -> SessionSet {
        if let session = session {
            return .isSet(session)
        } else {
            return .notSet
        }
    }

    static func fromNilableResult(_ res: Result<Session?, ServicesError>) -> Result<SessionSet, ServicesError> {
        res.map {
            fromNilable($0)
        }
    }
}

enum SessionState: Equatable {
    case result(Result<SessionSet, ServicesError>)
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

    // Convenience
    func isReady() -> Bool {
        if case .result(.success(.isSet(let session))) = self {
            return session.isReady
        } else {
            return false
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

        sessionSubject = CurrentValueSubject(.result(SessionSet.fromNilableResult(localSessionManager.getSession())))
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
            sessionSubject.send(.result(.success(.deleted)))
            uiNotifier.show(.success("Session deleted"))
        case .failure(let e):
            log.e("Couldn't delete session locally: \(e)")
            uiNotifier.show(.error("Couldn't delete session."))
        }
        return res
    }
}

class NoopCurrentSessionService: CurrentSessionService {
    var session: AnyPublisher<SessionState, Never> = Just(.result(.success(.notSet)))
        .eraseToAnyPublisher()

    func setSessionState(_ state: SessionState) {}
    func deleteSessionLocally() -> Result<(), ServicesError> { return .success(()) }
}
