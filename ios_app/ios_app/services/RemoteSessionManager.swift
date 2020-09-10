import Foundation

protocol RemoteSessionManager {
    func create()
    func join(link: SessionLink)
    func refresh()
}

class RemoteSessionManagerImpl: RemoteSessionManager {
    private let sessionService: SessionService
    private let currentSessionService: CurrentSessionService

    init(sessionService: SessionService, currentSessionService: CurrentSessionService) {
        self.sessionService = sessionService
        self.currentSessionService = currentSessionService
    }

    func create() {
        currentSessionService.setSessionResult(sessionService.createSession().map { $0 })
    }

    func join(link: SessionLink) {
        currentSessionService.setSessionResult(sessionService.joinSession(link: link).map { $0 })
    }

    func refresh() {
        currentSessionService.setSessionResult(sessionService.refreshSessionData().map { $0 })
    }
}
