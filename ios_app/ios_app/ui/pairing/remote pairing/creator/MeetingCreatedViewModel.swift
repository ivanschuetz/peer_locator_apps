import Foundation
import SwiftUI
import Combine

class MeetingCreatedViewModel: ObservableObject {
    @Published var linkText: String = ""
    @Published var linkUrl: URL? = nil
    @Published var sessionLinkInput: String = ""
    @Published var showLoading: Bool = false

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

        sessionCancellable = sessionService.session
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handle(sessionRes: $0)
            }
    }

    private func handle(sessionRes: SessionState) {
        switch sessionRes {
        case .result(.success(let session)):
            if let session = session.asNilable() {
                let link = session.id.createLink()
                log.d("Created session link: \(link)", .ui)
                linkUrl = link.url
                linkText = link.url.absoluteString
            }
            showLoading = false

        case .result(.failure(let e)):
            // If there are issues retrieving session this screen normally shouldn't be presented
            // TODO ensure that only one message of a type shows at a time
            let msg = "Couldn't retrieve session: \(e). NOTE: shouldn't happen in this screen."
            log.e(msg, .ui)
            showLoading = false

        case .progress:
            showLoading = true
        }
    }

    func onCopyLinkTap() {
        clipboard.putInClipboard(text: linkText)
        uiNotifier.show(.success("Copied link to clipboard"))
        log.d("Copied link to clipboard: \(linkText)", .ui)
    }

    // For dev
    func onUpdateStatusTap() {
        sessionManager.refresh()
    }

    func onDeleteSessionTap() -> Bool {
        !sessionManager.delete().isFailure()
    }

    func onSettingsButtonTap() {
        settingsShower.show()
    }

    deinit {
        log.d("View model deinit", .ui)
    }
}
