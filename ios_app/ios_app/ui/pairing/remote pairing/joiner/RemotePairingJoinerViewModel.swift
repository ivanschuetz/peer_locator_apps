import Foundation
import SwiftUI
import Combine

class RemotePairingJoinerViewModel: ObservableObject {
    @Published var sessionLinkInput: String = ""
    @Published var navigateToJoinedView: Bool = false
    @Published var showLoading: Bool = false

    private let sessionManager: RemoteSessionManager
    private let clipboard: Clipboard
    private let uiNotifier: UINotifier
    private let settingsShower: SettingsShower
    
    private let observeSession = CurrentValueSubject<Bool, Never>(false)

    private var sessionCancellable: Cancellable?

    init(sessionManager: RemoteSessionManager, sessionService: CurrentSessionService, clipboard: Clipboard,
         uiNotifier: UINotifier, settingsShower: SettingsShower) {
        self.sessionManager = sessionManager
        self.clipboard = clipboard
        self.uiNotifier = uiNotifier
        self.settingsShower = settingsShower

        sessionCancellable = sessionService.session
            .withLatestFrom(observeSession, resultSelector: { ($0, $1) })
            .compactMap{ sessionRes, switchValue -> SessionState? in
                if switchValue { return sessionRes } else { return nil }
            }
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionRes in
                self?.handleSessionState(sessionRes)
            }
    }

    private func handleSessionState(_ sessionState: SessionState) {
        switch sessionState {
        case .result(.success(let session)):
            if let session = session {
                if session.createdByMe {
                    // TODO revise this. Ideally we shouldn't throw fatal errors.
                    fatalError("Invalid state: If I'm in joiner view, I can't have created the session.")
                }
                navigateToJoinedView = true
            }

            observeSession.send(false)
            showLoading = false

        case .result(.failure(let e)):
            let msg = "Couldn't retrieve session: \(e)"
            log.e(msg, .ui)

            observeSession.send(false)
            showLoading = false

        case .progress:
            showLoading = true
        }
    }

    func joinSession() {
        let trimmed = sessionLinkInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            log.e("Session link is empty.", .session)
            uiNotifier.show(.error("The session link is empty."))
            return
        }
        guard let url = URL(string: trimmed) else {
            log.e("Invalid session link: \(trimmed).", .session)
            uiNotifier.show(.error("Invalid session link: \(trimmed)."))
            return
        }
        guard let sessionLink = SessionLink(url: url) else {
            log.e("Invalid session url: \(url).", .session)
            uiNotifier.show(.error("Invalid session link: \(url)."))
            return
        }
        observeSession.send(true)
        sessionManager.join(sessionId: sessionLink.sessionId)
    }
    
    func onSettingsButtonTap() {
        settingsShower.show()
    }

    func onPasteLinkTap() {
        sessionLinkInput = clipboard.getFromClipboard()
    }

    deinit {
        log.d("View model deinit", .ui)
    }
}
