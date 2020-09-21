import Foundation
import Combine
import SwiftUI

enum RootViewState {
    case noMeeting

    // For now only a "waiting" screen, for simplicity
    // maybe we can integrate creating/joined only as text
//    case meetingWaiting
//    case meetingCreated // "Session created!" "Waiting for the other peer to accept"
//    case meetingJoined // "Session joined!" "Waiting for the other peer to acknowledge"

//    case meetingReady "the meeting is ready!" but should probably be a dialog/notification

    case meetingActive
}

class RootViewModel: ObservableObject {
    private let sessionService: CurrentSessionService
    private let uiNotifier: UINotifier

    @Published var state: RootViewState = .noMeeting
    @Published var showSettingsModal: Bool = false

    private var didLaunchCancellable: AnyCancellable?
    private var sessionStateCancellable: AnyCancellable?
    private var showSettingsCancellable: AnyCancellable?

    init(sessionService: CurrentSessionService, uiNotifier: UINotifier, settingsShower: SettingsShower,
         appEvents: AppEvents) {
        self.sessionService = sessionService
        self.uiNotifier = uiNotifier

        didLaunchCancellable = appEvents.events
            .filter { $0 == .didLaunch }
            .withLatestFrom(sessionService.session)
            .sink { [weak self] sessionRes in
                self?.handleSessionStateOnAppLaunched(sessionRes)
            }

        sessionStateCancellable = sessionService.session
            .sink { [weak self] sessionRes in
                self?.handleSessionState(sessionRes)
            }

        showSettingsCancellable = settingsShower.showing.sink { [weak self] showing in
            self?.showSettingsModal = showing
        }
    }

    private func handleSessionStateOnAppLaunched(_ sessionRes: Result<Session?, ServicesError>) {
        updateState(sessionRes)
    }

    // When session is updated, update view only if it's that it has been activated (to transition to meeting view)
    // otherwise when we manipulate the session during session pairing, we will activate navigation. We don't want this.
    // Note that this can cause duplicate navigation events with handleSessionStateOnAppLaunched
    // but we don't react to duplicate navigation events, so not an issue.
    private func handleSessionState(_ sessionRes: Result<Session?, ServicesError>) {
        switch sessionRes {
        case .success(let session):
            if let session = session, session.isReady {
                updateState(sessionRes)
            }
        case .failure(let e):
            log.e("Session failure state: \(e)", .session)
        }
    }

    private func updateState(_ sessionRes: Result<Session?, ServicesError>) {
        let viewState = toViewState(sessionRes: sessionRes)

        if viewState == state {
            return
        }

        log.d("New session state in root: \(sessionRes), view state: \(viewState)", .session)
        state = viewState

        if case .failure(let e) = sessionRes {
            uiNotifier.show(.error("Error retrieving session: \(e)"))
        }
    }

    deinit {
        log.d("View model deinit", .ui)
    }
}

private func toViewState(sessionRes: Result<Session?, ServicesError>) -> RootViewState {
    log.d("Root view model: toViewState: \(sessionRes)", .ui)
    switch sessionRes {
    case .success(let session):
        if let session = session {
            if session.isReady {
                return .meetingActive
            } else {
                return .noMeeting
            }
        } else {
            return .noMeeting
        }
    case .failure:
        return .noMeeting // TODO error view state
    }
}
