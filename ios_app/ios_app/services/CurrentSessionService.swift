import Combine

protocol CurrentSessionService {
    var session: AnyPublisher<Result<SharedSessionData?, ServicesError>, Never> { get }
    func create()
    func join(link: SessionLink)
    func refresh()

    // Locally opposed to the automatic deletion in the backend after participants have exchanged data
    // Here the user isn't interested in the session anymore: the session data / keys / participants data are removed
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
//            .handleEvents(receiveOutput: { sessionData in
//                log.d("Current session was updated to: \(sessionData)", .session)
//            })
            .eraseToAnyPublisher()
    }
 
    func create() {
        sessionSubject.send(sessionService.createSession().map { $0 } )
    }

    func join(link: SessionLink) {
        sessionSubject.send(sessionService.joinSession(link: link).map { $0 } )
    }

    func refresh() {
        sessionSubject.send(sessionService.refreshSessionData().map { $0 } )
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
