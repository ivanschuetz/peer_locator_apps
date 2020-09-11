import Foundation
import SwiftUI
import Combine

class RemotePairingRoleSelectionViewModel: ObservableObject {
    private let remoteSessionManager: RemoteSessionManager
    private let sessionService: CurrentSessionService

    @Published var navigateToCreateView: Bool = false

    private var sessionCancellable: AnyCancellable?

    init(remoteSessionManager: RemoteSessionManager, sessionService: CurrentSessionService, uiNotifier: UINotifier) {
        self.remoteSessionManager = remoteSessionManager
        self.sessionService = sessionService

        sessionCancellable = sessionService.session
            .sink(receiveCompletion: { completion in }) { [weak self] sessionRes in
                switch sessionRes {
                case .success(let session):
                    if let session = session {
                        // filter joined event: since this vm stays in the stack,
                        // if we don't filter, when we join a session it will navigate to create first
                        if session.createdByMe {
                            log.d("Session created, navigating to create view", .ui)
                            self?.navigateToCreateView = true
                        }
                    }
                case .failure(let e):
                    log.e("Current session error: \(e)", .session)
                    uiNotifier.show(.error("Current session error: \(e)"))
                    // TODO handle
                }
        }
    }

    func onCreateSessionTap() {
        remoteSessionManager.create()
    }
}
