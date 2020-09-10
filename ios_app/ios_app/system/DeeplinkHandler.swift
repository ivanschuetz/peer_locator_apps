import Foundation

protocol DeeplinkHandler {
    func handle(link: URL)
}

class DeeplinkHandlerImpl: DeeplinkHandler {
    private let sessionManager: RemoteSessionManager
    private let colocatedPasswordService: ColocatedPairingPasswordService

    init(sessionManager: RemoteSessionManager, colocatedPasswordService: ColocatedPairingPasswordService) {
        self.sessionManager = sessionManager
        self.colocatedPasswordService = colocatedPasswordService
    }

    func handle(link: URL) {
        log.d("Handling deeplink: \(link)", .deeplink)

        guard link.scheme == "ploc" else {
            log.e("Unexpected: invalid scheme: \(String(describing: link.scheme))", .deeplink)
            return
        }

        if let passwordLink = ColocatedPeeringPasswordLink(value: link) {
            colocatedPasswordService.processPassword(passwordLink.extractPassword())
        } else {
            // TODO SessionLink failable init, validates that it has session id
            sessionManager.join(link: SessionLink(value: link))
        }
    }
}
