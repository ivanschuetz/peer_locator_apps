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

    // For dev
    func updateSession() {
        sessionManager.refresh()
    }

    func onSettingsButtonTap() {
        settingsShower.show()
    }

    func onDeleteSessionTap() -> Bool {
        !sessionManager.delete().isFailure()
    }

    deinit {
        log.d("View model deinit", .ui)
    }
}
