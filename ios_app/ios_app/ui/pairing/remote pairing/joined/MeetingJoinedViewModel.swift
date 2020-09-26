import Foundation
import SwiftUI
import Combine

class MeetingJoinedViewModel: ObservableObject {
    @Published var sessionLinkInput: String = ""
    @Published var showSettingsModal: Bool = false

    private let sessionManager: RemoteSessionManager
    private let clipboard: Clipboard
    private let uiNotifier: UINotifier

    init(sessionManager: RemoteSessionManager, sessionService: CurrentSessionService, clipboard: Clipboard,
         uiNotifier: UINotifier) {
        self.sessionManager = sessionManager
        self.clipboard = clipboard
        self.uiNotifier = uiNotifier
    }

    // For dev
    func updateSession() {
        sessionManager.refresh()
    }

    func onSettingsButtonTap() {
        showSettingsModal = true
    }

    func onDeleteSessionTap() -> Bool {
        !sessionManager.delete().isFailure()
    }

    deinit {
        log.d("View model deinit", .ui)
    }
}
