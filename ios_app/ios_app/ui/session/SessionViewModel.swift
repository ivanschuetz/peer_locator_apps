import Foundation
import Combine
import SwiftUI

class SessionViewModel: ObservableObject {
    private let sessionService: SessionService
    private let p2pService: P2pService

    @Published var createdSessionLink: String = ""

    @Published var sessionStartedMessage: String = ""

    @Published var sessionId: String = ""

    init(sessionService: SessionService, p2pService: P2pService) {
        self.sessionService = sessionService
        self.p2pService = p2pService
    }

    func createSession() {
        switch sessionService.createSession() {
        case .success(let sessionLink):
            log.d("Created session with link: \(sessionLink)", .ui)
            createdSessionLink = sessionLink.value

        case .failure(let error):
            log.e("Failure creating session! \(error)", .session)
            // TODO notification
        }
    }

    func joinSession() {
        guard !sessionId.isEmpty else {
            log.e("Session id is empty. Nothing to join", .session)
            // TODO this state should be impossible: if there's no link in input, don't allow to press join
            return
        }

        switch sessionService.joinSession(sessionId: SessionId(value: sessionId)) {
        case .success(let session):
            sessionStartedMessage = "Session joined: \(session)"
        case .failure(let error):
            log.e("Failure joining session! \(error)", .session)
            // TODO notification
        }
    }

    // TODO call when opening the screen, maybe also pull to refresh "update participants status..."
    // show a progress indicator when checking, next to the sessions status label
    // maybe also button? "is the session ready?" with
    // text yes: "all the participants are connected and ready to meet", no: "not all participants are ready"
    func refreshSessionData() {
        switch sessionService.refreshSessionData() {
        case .success(let isReady):
            switch isReady {
            case .yes: sessionStartedMessage = "Session is ready!"
            case .no: sessionStartedMessage = "Session not ready yet"
            }
        case .failure(let error):
            log.e("Failure refreshing session data: \(error)", .session)
            // TODO notification
        }
    }

    func activateSession() {
        p2pService.activateSession()
    }
}
