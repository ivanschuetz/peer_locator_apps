import Foundation

protocol RemoteSessionManager {
    func create()
    func join(sessionId: SessionId)
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

    func join(sessionId: SessionId) {
        currentSessionService.setSessionResult(sessionService.joinSession(id: sessionId).map { $0 })
    }

    func refresh() {
        currentSessionService.setSessionResult(sessionService.refreshSessionData().map { $0 })
    }
}
