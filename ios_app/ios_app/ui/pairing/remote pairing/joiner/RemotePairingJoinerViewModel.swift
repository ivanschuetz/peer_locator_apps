import Foundation
import SwiftUI
import Combine

class RemotePairingJoinerViewModel: ObservableObject {
    @Published var sessionLinkInput: String = ""
    @Published var navigateToJoinedView: Bool = false

    private let sessionManager: RemoteSessionManager
    private let clipboard: Clipboard
    private let uiNotifier: UINotifier
    private let settingsShower: SettingsShower

    private var sessionCancellable: Cancellable?

    init(sessionManager: RemoteSessionManager, sessionService: CurrentSessionService, clipboard: Clipboard,
         uiNotifier: UINotifier, settingsShower: SettingsShower) {
        self.sessionManager = sessionManager
        self.clipboard = clipboard
        self.uiNotifier = uiNotifier
        self.settingsShower = settingsShower

        sessionCancellable = sessionService.session.sink { [weak self] sharedSessionDataRes in
            switch sharedSessionDataRes {
            case .success(let sessionData):
                if let sessionData = sessionData {
                    if sessionData.createdByMe {
                        // TODO revise this. Ideally we shouldn't throw fatal errors.
                        fatalError("Invalid state: If I'm in joiner view, I can't have created the session.")
                    }
                    self?.navigateToJoinedView = true
                }
            case .failure(let e):
                let msg = "Couldn't retrieve session: \(e)"
                log.e(msg, .ui)
                uiNotifier.show(.error(msg))
            }
        }
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
        guard let sessionLink = SessionLink(url: url) else {
            log.e("Invalid session url: \(url). Nothing to join", .session)
            uiNotifier.show(.error("Invalid session url: \(url). Nothing to join"))
            return
        }
        sessionManager.join(sessionId: sessionLink.sessionId)
    }
    
    func onSettingsButtonTap() {
        settingsShower.show()
    }

    func onPasteLinkTap() {
        sessionLinkInput = clipboard.getFromClipboard()
    }
}
