import Combine

protocol CurrentSessionService {
    var session: AnyPublisher<Result<SharedSessionData?, ServicesError>, Never> { get }
    func create()
    func join(link: SessionLink)
    func refresh()
}

class CurrentSessionServiceImpl: CurrentSessionService {
    private let sessionSubject: CurrentValueSubject<Result<SharedSessionData?, ServicesError>, Never>

    lazy var session: AnyPublisher<Result<SharedSessionData?, ServicesError>, Never> = sessionSubject
        .eraseToAnyPublisher()

    private let sessionService: SessionService

    init(sessionService: SessionService) {
        self.sessionService = sessionService
//        sessionSubject.send(completion: .failure(.general("")))
        sessionSubject = CurrentValueSubject(sessionService.currentSession())
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
}
