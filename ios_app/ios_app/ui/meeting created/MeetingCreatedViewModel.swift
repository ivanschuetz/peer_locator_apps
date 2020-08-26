import Foundation
import SwiftUI
import Combine

class MeetingCreatedViewModel: ObservableObject {
    @Published var link: String = ""

    private let sessionService: CurrentSessionService
    private let clipboard: Clipboard
    private let uiNotifier: UINotifier

    private var sessionCancellable: Cancellable?

    init(sessionService: CurrentSessionService, clipboard: Clipboard, uiNotifier: UINotifier) {
        self.sessionService = sessionService
        self.clipboard = clipboard
        self.uiNotifier = uiNotifier

        sessionCancellable = sessionService.session.sink { [weak self] sharedSessionDataRes in
            switch sharedSessionDataRes {
            case .success(let sessionData):
                if let sessionData = sessionData {
                    self?.link = sessionData.id.createLink().value
                }
            case .failure(let e):
                // If there are issues retrieving session this screen normally shouldn't be presented
                // TODO ensure that only one message of a type shows at a time
                let msg = "Couldn't retrieve session: \(e). NOTE: shouldn't happen in this screen."
                log.e(msg, .ui)
                uiNotifier.show(.error(msg))
            }
        }
    }

    func onCopyLinkTap() {
        // TODO check that link isn't empty
        clipboard.putInClipboard(text: link)
        // TODO notification
        uiNotifier.show(.success("Copied link to clipboard: \(link)"))
        log.d("Copied link to clipboard: \(link)", .ui)
    }

    func updateSession() {
        sessionService.refresh()
    }
}
