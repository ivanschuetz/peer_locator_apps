import Foundation
import Combine
import SwiftUI

class SessionViewModel: ObservableObject {
    private let sessionService: CurrentSessionService
    private let clipboard: Clipboard
    private let uiNotifier: UINotifier

    @Published var createdSessionLink: String = ""
    @Published var sessionStartedMessage: String = ""
//    @Published var sessionLinkInput: String = "vemeet://54D3B240-29DA-4569-80B3-1B07DE045000"
    @Published var sessionLinkInput: String = ""

    private var sessionCancellable: AnyCancellable?

    init(sessionService: CurrentSessionService, clipboard: Clipboard, uiNotifier: UINotifier) {
        self.sessionService = sessionService
        self.clipboard = clipboard
        self.uiNotifier = uiNotifier

        sessionCancellable = sessionService.session
            .sink(receiveCompletion: { completion in }) { [weak self] sessionRes in
                switch sessionRes {
                case .success(let session):
                    self?.createdSessionLink = session?.id.createLink().value.absoluteString ?? ""
                case .failure(let e):
                    log.e("Current session error: \(e)", .session)
                    uiNotifier.show(.error("Current session error: \(e)"))
                    // TODO handle
                }
        }
    }

    func createSession() {
        sessionService.create()
    }

    func joinSession() {
        guard !sessionLinkInput.isEmpty else {
            log.e("Session link is empty. Nothing to join", .session)
            uiNotifier.show(.error("Session link is empty. Nothing to join"))
            // TODO this state should be impossible: if there's no link in input, don't allow to press join
            return
        }
        guard let url = URL(string: sessionLinkInput) else {
            log.e("Invalid session link input: \(sessionLinkInput). Nothing to join", .session)
            uiNotifier.show(.error("Invalid session link input: \(sessionLinkInput). Nothing to join"))
            return
        }

        sessionService.join(link: SessionLink(value: url))
    }

    // TODO call when opening the screen, maybe also pull to refresh "update participants status..."
    // show a progress indicator when checking, next to the sessions status label
    // maybe also button? "is the session ready?" with
    // text yes: "all the participants are connected and ready to meet", no: "not all participants are ready"
    func refreshSessionData() {
        sessionService.refresh()
    }

    func onCopyLinkTap() {
        // TODO check that link isn't empty
        clipboard.putInClipboard(text: createdSessionLink)
        // TODO notification
        uiNotifier.show(.success("Copied link to clipboard: \(createdSessionLink)"))
        log.d("Copied link to clipboard: \(createdSessionLink)", .ui)
    }

    func onPasteLinkTap() {
        sessionLinkInput = clipboard.getFromClipboard()
    }
}
