import Combine

protocol CurrentSessionService {
    var session: AnyPublisher<Result<Session?, ServicesError>, Never> { get }

    func setSessionResult(_ result: Result<Session?, ServicesError>)

    // Locally opposed to the automatic deletion in the backend after peers have exchanged data
    // Here the user isn't interested in the session anymore: the session data / keys / peers data are removed
    func deleteSessionLocally()
}

class CurrentSessionServiceImpl: CurrentSessionService {
    private let sessionSubject: CurrentValueSubject<Result<Session?, ServicesError>, Never>

    let session: AnyPublisher<Result<Session?, ServicesError>, Never>

    private let localSessionManager: LocalSessionManager
    private let uiNotifier: UINotifier

    init(localSessionManager: LocalSessionManager, uiNotifier: UINotifier) {
        self.localSessionManager = localSessionManager
        self.uiNotifier = uiNotifier

        sessionSubject = CurrentValueSubject(localSessionManager.getSession())
        session = sessionSubject
//            .handleEvents(receiveOutput: { session in
//                log.d("Current session was updated to: \(session)", .session)
//            })
            .eraseToAnyPublisher()
    }

    func setSessionResult(_ result: Result<Session?, ServicesError>) {
        sessionSubject.send(result)
    }

    func deleteSessionLocally() {
        switch localSessionManager.clear() {
        case .success:
            sessionSubject.send(.success(nil))
            uiNotifier.show(.success("Session deleted"))
        case .failure(let e):
            log.e("Couldn't delete session locally: \(e)")
            uiNotifier.show(.error("Error deleting sesion: \(e)"))
        }
    }
}

class NoopCurrentSessionService: CurrentSessionService {
    var session: AnyPublisher<Result<Session?, ServicesError>, Never> = Just(.success(nil))
        .eraseToAnyPublisher()

    func setSessionResult(_ result: Result<Session?, ServicesError>) {}
    func deleteSessionLocally() {}
}
