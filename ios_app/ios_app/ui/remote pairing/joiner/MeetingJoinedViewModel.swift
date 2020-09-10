import Foundation
import SwiftUI
import Combine

class MeetingJoinedViewModel: ObservableObject {
    @Published var link: String = ""

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
                    self?.link = sessionData.id.createLink().value.absoluteString
                }
            case .failure(let e):
                // If there are issues retrieving session this screen normally shouldn't be presented
                let msg = "Couldn't retrieve session: \(e). NOTE: shouldn't happen in this screen."
                log.e(msg, .ui)
                uiNotifier.show(.error(msg))
            }
        }
    }

    func updateSession() {
        sessionManager.refresh()
    }

    func onSettingsButtonTap() {
        settingsShower.show()
    }
}
