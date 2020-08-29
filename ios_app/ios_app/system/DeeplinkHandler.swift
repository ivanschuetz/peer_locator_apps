import Foundation

protocol DeeplinkHandler {
    func handle(link: URL)
}

class DeeplinkHandlerImpl: DeeplinkHandler {
    private let sessionService: CurrentSessionService

    init(sessionService: CurrentSessionService) {
        self.sessionService = sessionService
    }

    func handle(link: URL) {
        log.d("Handling deeplink: \(link)", .deeplink)

        guard link.scheme == "ploc" else {
            log.e("Unexpected: invalid scheme: \(String(describing: link.scheme))", .deeplink)
            return
        }

        // TODO SessionLink failable init, validates that it has session id
        sessionService.join(link: SessionLink(value: link))
    }
}
