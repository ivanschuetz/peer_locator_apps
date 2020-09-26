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

    private var didLaunchCancellable: AnyCancellable?
    private var sessionStateCancellable: AnyCancellable?
    private var showSettingsCancellable: AnyCancellable?

    init(sessionService: CurrentSessionService, uiNotifier: UINotifier, appEvents: AppEvents) {
        self.sessionService = sessionService
        self.uiNotifier = uiNotifier

        didLaunchCancellable = appEvents.events
            .filter { $0 == .didLaunch }
            .withLatestFrom(sessionService.session)
            .sink { [weak self] sessionRes in
                self?.handleSessionStateOnAppLaunched(sessionRes)
            }

        sessionStateCancellable = sessionService.session
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionRes in
                self?.handleSessionState(sessionRes)
            }
    }

    private func handleSessionStateOnAppLaunched(_ sessionRes: SessionState) {
        updateState(sessionRes)
    }

    // When session is updated, update view only if it's that it has been activated (to transition to meeting view)
    // otherwise when we manipulate the session during session pairing, we will activate navigation. We don't want this.
    // Note that this can cause duplicate navigation events with handleSessionStateOnAppLaunched
    // but we don't react to duplicate navigation events, so not an issue.
    private func handleSessionState(_ sessionRes: SessionState) {
        switch sessionRes {
        case .result(.success(let sessionSet)):
            switch sessionSet {
            case .isSet(let session):
                // When a session was successfully initiated, we want root to show meeting view
                if session.isReady {
                    updateState(sessionRes)
                }
            // When the session was deleted, we want root to update navigation (go back to session type view)
            case .deleted: updateState(sessionRes)
            // Do nothing
            case .notSet: break
            }
        case .result(.failure(let e)):
            log.e("Session failure state: \(e)", .session)
        case .progress: break
        }
    }

    private func updateState(_ sessionRes: SessionState) {
        guard let viewState = toViewState(sessionRes: sessionRes) else {
            // No changes (.progress state: this is an overlay, view state here stays the same)
            return
        }

        if viewState == state {
            return
        }

        log.d("New session state in root: \(sessionRes), view state: \(viewState)", .session)
        state = viewState

        if case .result(.failure(let e)) = sessionRes {
            log.e("Error retrieving session: \(e)", .ui)
            uiNotifier.show(.error("Couldn't retrieve sessiond data."))
        }
    }

    deinit {
        log.d("View model deinit", .ui)
    }
}

private func toViewState(sessionRes: SessionState) -> RootViewState? {
    log.d("Root view model: toViewState: \(sessionRes)", .ui)
    switch sessionRes {
    case .result(.success(let sessionSet)):
        switch sessionSet {
        case .isSet(let session):
            if session.isReady {
                return .meetingActive
            } else {
                return .noMeeting
            }
        case .deleted, .notSet:
            return .noMeeting
        }
    case .result(.failure):
        return .noMeeting // TODO error view state
    case .progress: return nil
    }
}
