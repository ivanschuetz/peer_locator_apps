import Foundation
import Combine
import SwiftUI

enum HomeViewState {
    case noMeeting

    // For now only a "waiting" screen, for simplicity
    // maybe we can integrate creating/joined only as text
//    case meetingWaiting
    case meetingCreated // "Session created!" "Waiting for the other participant to accept"
    case meetingJoined // "Session joined!" "Waiting for the other participant to acknowledge"

//    case meetingReady "the meeting is ready!" but should probably be a dialog/notification

    case meetingActive
}

class HomeViewModel: ObservableObject {
    private let sessionService: CurrentSessionService
    private let uiNotifier: UINotifier

    @Published var state: HomeViewState = .noMeeting
    @Published var showSettingsModal: Bool = false

    private var stateCancellable: AnyCancellable?
    private var showSettingsCancellable: AnyCancellable?

    init(sessionService: CurrentSessionService, uiNotifier: UINotifier, settingsShower: SettingsShower) {
        self.sessionService = sessionService
        self.uiNotifier = uiNotifier

        stateCancellable = sessionService.session.sink { [weak self] sessionRes in
            self?.handleSessionState(sessionRes)
        }
        showSettingsCancellable = settingsShower.showing.sink { [weak self] showing in
            self?.showSettingsModal = showing
        }
    }

    private func handleSessionState(_ sessionRes: Result<SharedSessionData?, ServicesError>) {
        let viewState = toViewState(sessionRes: sessionRes)
        log.d("New session state in home: \(sessionRes), view state: \(viewState)", .session)
        state = viewState

        if case .failure(let e) = sessionRes {
            uiNotifier.show(.error("Error retrieving session: \(e)"))
        }
    }
}

private func toViewState(sessionRes: Result<SharedSessionData?, ServicesError>) -> HomeViewState {
    switch sessionRes {
    case .success(let session):
        if let session = session {
            switch session.isReady {
            case .yes: return .meetingActive
            case .no:
                if session.createdByMe {
                    return .meetingCreated
                } else {
                    return .meetingJoined
                }
            }
        } else {
            return .noMeeting
        }
    case .failure:
        return .noMeeting // TODO error view state
    }
}
