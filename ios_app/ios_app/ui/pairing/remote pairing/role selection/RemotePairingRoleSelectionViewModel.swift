import Foundation
import SwiftUI
import Combine

enum RemotePairingRoleDestination {
    case create, join, none
}

class RemotePairingRoleSelectionViewModel: ObservableObject {
    @Published var destination: RemotePairingRoleDestination = .none
    @Published var navigationActive: Bool = false
    @Published var showLoading: Bool = false

    private let remoteSessionManager: RemoteSessionManager
    private let sessionService: CurrentSessionService
    private let settingsShower: SettingsShower
    private let uiNotifier: UINotifier

    private let observeSession = CurrentValueSubject<Bool, Never>(false)

    private var sessionCancellable: AnyCancellable?

    init(remoteSessionManager: RemoteSessionManager, sessionService: CurrentSessionService, uiNotifier: UINotifier,
         settingsShower: SettingsShower) {
        self.remoteSessionManager = remoteSessionManager
        self.sessionService = sessionService
        self.settingsShower = settingsShower
        self.uiNotifier = uiNotifier

        sessionCancellable = sessionService.session
            .withLatestFrom(observeSession, resultSelector: {
                ($0, $1)
            })
            .compactMap{ sessionRes, switchValue -> SessionState? in
                if switchValue { return sessionRes } else { return nil }
            }
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionRes in
                self?.handleSessionStateAfterTapCreate(sessionRes)
            }
    }

    private func handleSessionStateAfterTapCreate(_ sessionState: SessionState) {
        switch sessionState {
        case .result(.success(let session)):
            if let session = session {
                // filter joined event: since this vm stays in the stack,
                // if we don't filter, when we join a session it will navigate to create first
                if session.createdByMe {
                    log.d("Session created, navigating to create view", .ui)
                    navigate(to: .create)
                } else {
                    // TODO happens in join session view after pasting the link and tapping on join!
                    // we need something to prevent cross-events between view models?
                    // we don't want to receive any navigation events here.
                    log.w("Received session update, session wasn't created by me so not navigating (see TODO).", .ui)
                }
            } else {
                log.v("Session is nil", .ui)
            }

            observeSession.send(false)
            showLoading = false

        case .result(.failure(let e)):
            // TODO message specific for networking errors.
            log.e("Current session error: \(e)", .session, .ui)
            uiNotifier.show(.error("Error creating create session. Please try again."))

            observeSession.send(false)
            showLoading = false

            // TODO handle
        case .progress:
            showLoading = true
        }
    }

    func onCreateSessionTap() {
        observeSession.send(true)
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

    deinit {
        log.d("View model deinit", .ui)
    }
}

// TODO operator for:
//.withLatestFrom(observeSession, resultSelector: { sessionRes, switchValue in
//    (sessionRes, switchValue)
//})
//.compactMap{ sessionRes, switchValue -> Result<Session?, ServicesError>? in
//    if switchValue {
//        return sessionRes
//    } else {
//        return nil
//    }
//}
// can't get the generics right!

//extension Publisher {
//
//    func withToggle<T>(_ toggle: T) -> Publishers.CompactMap<Self, Output> where T: Publisher, Self.Failure == T.Failure, T.Output == Bool {
//        withLatestFrom(toggle, resultSelector: { this, toggle in
//            (this, toggle)
//        })
////        .map { this, toggle in
////            return this
////        }
//
//        .compactMap{ this, toggle -> Self.Output? in
//            return nil
////            if toggle {
////                return this
////            } else {
////                return nil
////            }
//        }
//    }
//}
