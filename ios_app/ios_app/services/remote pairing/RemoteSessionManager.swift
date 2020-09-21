import Foundation

protocol RemoteSessionManager {
    func create()
    func join(sessionId: SessionId)
    func refresh()
    func delete() -> Result<(), ServicesError>
}

class RemoteSessionManagerImpl: RemoteSessionManager {
    private let sessionService: RemoteSessionService
    private let currentSessionService: CurrentSessionService

    init(sessionService: RemoteSessionService, currentSessionService: CurrentSessionService) {
        self.sessionService = sessionService
        self.currentSessionService = currentSessionService
    }

    func create() {
        log.d("Creating session", .session)
        currentSessionService.setSessionResult(sessionService.createSession().map { $0 })
    }

    func join(sessionId: SessionId) {
        log.d("Joining session: \(sessionId)", .session)
        currentSessionService.setSessionResult(sessionService.joinSession(id: sessionId).map { $0 })
    }

    func refresh() {
        log.d("Refreshing session", .session)
        currentSessionService.setSessionResult(sessionService.refreshSession().map { $0 })
    }

    func delete() -> Result<(), ServicesError> {
        log.d("Deleting session", .session)
        return currentSessionService.deleteSessionLocally()
    }
}
