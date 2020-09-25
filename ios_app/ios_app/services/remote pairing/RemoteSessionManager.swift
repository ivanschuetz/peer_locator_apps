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
        currentSessionService.setSessionState(.progress)
        DispatchQueue.global(qos: .background).async {
            self.handleCreateOrJoinSessionStateResult((self.sessionService.createSession()))
        }
    }

    func join(sessionId: SessionId) {
        log.d("Joining session: \(sessionId)", .session)
        currentSessionService.setSessionState(.progress)
        DispatchQueue.global(qos: .background).async {
            self.handleCreateOrJoinSessionStateResult((self.sessionService.joinSession(id: sessionId)))
        }
    }

    private func handleCreateOrJoinSessionStateResult(_ result: Result<Session, ServicesError>) {
        currentSessionService.setSessionState(.result(result.map { .isSet($0) }))
    }

    func refresh() {
        log.d("Refreshing session", .session)
        // Note: no progress state. This is only for visuals (show progress indicator) and refresh
        // done in the background.
        DispatchQueue.global(qos: .background).async {
            self.currentSessionService.setSessionState(.result(self.sessionService.refreshSession().map { .isSet($0) }))
        }
    }

    func delete() -> Result<(), ServicesError> {
        log.d("Deleting session", .session)
        return currentSessionService.deleteSessionLocally()
    }
}
