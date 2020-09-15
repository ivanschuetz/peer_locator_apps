import Combine

// TODO rename SessionService? (since SessionService will be renamed in RemoteSessionService)
protocol CurrentSessionService {
    var session: AnyPublisher<Result<SharedSessionData?, ServicesError>, Never> { get }

    func setSessionResult(_ result: Result<SharedSessionData?, ServicesError>)

    // Locally opposed to the automatic deletion in the backend after peers have exchanged data
    // Here the user isn't interested in the session anymore: the session data / keys / peers data are removed
    func deleteSessionLocally()
}

class CurrentSessionServiceImpl: CurrentSessionService {
    private let sessionSubject: CurrentValueSubject<Result<SharedSessionData?, ServicesError>, Never>

    let session: AnyPublisher<Result<SharedSessionData?, ServicesError>, Never>

    private let sessionService: SessionService
    private let uiNotifier: UINotifier

    init(sessionService: SessionService, uiNotifier: UINotifier) {
        self.sessionService = sessionService
        self.uiNotifier = uiNotifier

        sessionSubject = CurrentValueSubject(sessionService.currentSession())
        session = sessionSubject
//            .handleEvents(receiveOutput: { session in
//                log.d("Current session was updated to: \(session)", .session)
//            })
            .eraseToAnyPublisher()
    }

    func setSessionResult(_ result: Result<SharedSessionData?, ServicesError>) {
        sessionSubject.send(result)
    }

    func deleteSessionLocally() {
        switch sessionService.deleteSessionLocally() {
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
    var session: AnyPublisher<Result<SharedSessionData?, ServicesError>, Never> = Just(.success(nil))
        .eraseToAnyPublisher()

    func setSessionResult(_ result: Result<SharedSessionData?, ServicesError>) {}
    func deleteSessionLocally() {}
}
