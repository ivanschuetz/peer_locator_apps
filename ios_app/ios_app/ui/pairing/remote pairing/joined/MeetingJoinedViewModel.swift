import Foundation
import SwiftUI
import Combine

class MeetingJoinedViewModel: ObservableObject {
    @Published var sessionLinkInput: String = ""

    private let sessionManager: RemoteSessionManager
    private let clipboard: Clipboard
    private let uiNotifier: UINotifier
    private let settingsShower: SettingsShower

    init(sessionManager: RemoteSessionManager, sessionService: CurrentSessionService, clipboard: Clipboard,
         uiNotifier: UINotifier, settingsShower: SettingsShower) {
        self.sessionManager = sessionManager
        self.clipboard = clipboard
        self.uiNotifier = uiNotifier
        self.settingsShower = settingsShower
    }

    func updateSession() {
        // TODO call when opening the screen, maybe also pull to refresh "update peers status..."
        // show a progress indicator when checking, next to the sessions status label
        // maybe also button? "is the session ready?" with
        // text yes: "all the peers are connected and ready to meet", no: "not all peers are ready"
        sessionManager.refresh()
    }

    func onSettingsButtonTap() {
        settingsShower.show()
    }
}

