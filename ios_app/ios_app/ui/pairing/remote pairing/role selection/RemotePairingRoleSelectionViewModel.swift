import Foundation
import SwiftUI
import Combine

enum RemotePairingRoleDestination {
    case create, join, none
}

class RemotePairingRoleSelectionViewModel: ObservableObject {
    @Published var destination: RemotePairingRoleDestination = .none
    @Published var navigationActive: Bool = false

    private let remoteSessionManager: RemoteSessionManager
    private let sessionService: CurrentSessionService
    private let settingsShower: SettingsShower

    private var sessionCancellable: AnyCancellable?

    init(remoteSessionManager: RemoteSessionManager, sessionService: CurrentSessionService, uiNotifier: UINotifier,
         settingsShower: SettingsShower) {
        self.remoteSessionManager = remoteSessionManager
        self.sessionService = sessionService
        self.settingsShower = settingsShower

        sessionCancellable = sessionService.session
            .sink { [weak self] sessionRes in
                switch sessionRes {
                case .success(let session):
                    if let session = session {
                        // filter joined event: since this vm stays in the stack,
                        // if we don't filter, when we join a session it will navigate to create first
                        if session.createdByMe {
                            log.d("Session created, navigating to create view", .ui)
                            self?.navigate(to: .create)
                        } else {
                            // TODO happens in join session view after pasting the link and tapping on join!
                            // we need something to prevent cross-events between view models?
                            // we don't want to receive any navigation events here.
                            log.w("Received session update, session wasn't created by me so not navigating (see TODO).", .ui)
                        }
                    } else {
                        log.v("Session is nil", .ui)
                    }
                case .failure(let e):
                    log.e("Current session error: \(e)", .session, .ui)
                    uiNotifier.show(.error("Current session error: \(e)"))
                    // TODO handle
                }
        }
    }

    func onCreateSessionTap() {
        remoteSessionManager.create()
    }

    func onJoinSessionTap() {
        navigate(to: .join)
    }

    func onSettingsButtonTap() {
        settingsShower.show()
    }
    
    private func navigate(to: RemotePairingRoleDestination) {
        log.d("Navigating to: \(to)", .ui)
        destination = to
        navigationActive = true
    }
}
