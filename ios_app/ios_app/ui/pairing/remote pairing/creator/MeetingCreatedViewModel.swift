import Foundation
import SwiftUI
import Combine

class MeetingCreatedViewModel: ObservableObject {
    @Published var linkText: String = ""
    @Published var linkUrl: URL? = nil
    @Published var sessionLinkInput: String = ""

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
            self?.handle(sessionDataRes: sharedSessionDataRes)
        }
    }

    private func handle(sessionDataRes: Result<SharedSessionData?, ServicesError>) {
        switch sessionDataRes {
        case .success(let sessionData):
            if let sessionData = sessionData {
                let link = sessionData.id.createLink()
                linkUrl = link.url
                linkText = link.url.absoluteString
            }
        case .failure(let e):
            // If there are issues retrieving session this screen normally shouldn't be presented
            // TODO ensure that only one message of a type shows at a time
            let msg = "Couldn't retrieve session: \(e). NOTE: shouldn't happen in this screen."
            log.e(msg, .ui)
            uiNotifier.show(.error(msg))
        }
    }

    func onCopyLinkTap() {
        // TODO check that link isn't empty
        clipboard.putInClipboard(text: linkText)
        // TODO notification
        uiNotifier.show(.success("Copied link to clipboard: \(String(describing: link))"))
        log.d("Copied link to clipboard: \(String(describing: link))", .ui)
    }

    func updateSession() {
        // TODO call when opening the screen, maybe also pull to refresh "update participants status..."
        // show a progress indicator when checking, next to the sessions status label
        // maybe also button? "is the session ready?" with
        // text yes: "all the participants are connected and ready to meet", no: "not all participants are ready"
        sessionManager.refresh()
    }

    func onSettingsButtonTap() {
        settingsShower.show()
    }
}
