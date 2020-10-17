import SwiftUI
import Combine

struct RootView: View {
    @ObservedObject private var viewModel: RootViewModel

    private let viewModelProvider: ViewModelProvider

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.root()
        self.viewModelProvider = viewModelProvider
    }

    var body: some View {
        viewForState(state: viewModel.state)
    }

    private func viewForState(state: RootViewState) -> some View {
        log.d("Updating root view for state: \(state)", .ui)
        switch state {
        case .noMeeting:
            return AnyView(noMeetingView())
        case .meetingActive:
            return AnyView(meetingActiveView())
        case .meetingCreated:
            return AnyView(meetingCreatedView())
        case .meetingJoined:
            return AnyView(meetingJoinedView())
        }
    }

    private func meetingCreatedView() -> some View {
        MeetingCreatedView(viewModelProvider: viewModelProvider)
    }

    private func meetingJoinedView() -> some View {
        MeetingJoinedView(viewModelProvider: viewModelProvider)
    }

    private func noMeetingView() -> some View {
        PairingTypeView(viewModelProvider: viewModelProvider)
    }

    private func meetingActiveView() -> some View {
        MeetingView(viewModelProvider: viewModelProvider)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(viewModelProvider: DummyViewModelProvider())
    }
}

class NoopBleEnabler: BleEnabler {
    func showEnableDialogIfDisabled() {}
}

class NoopRemoteSessionManager: RemoteSessionManager {
    func create() {}
    func join(sessionId: SessionId) {}
    func refresh() {}
    func delete() -> Result<(), ServicesError> { return .success(()) }
}
