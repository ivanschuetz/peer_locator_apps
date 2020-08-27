import SwiftUI
import Combine

struct HomeView: View {
    @ObservedObject private var viewModel: HomeViewModel

    private let sessionViewModel: SessionViewModel
    private let meetingCreatedViewModel: MeetingCreatedViewModel
    private let meetingJoinedViewModel: MeetingJoinedViewModel
    private let meetingViewModel: MeetingViewModel

    // TODO review states+view models: view models are eagerly instantiated, so we've e.g. a session created
    // view model active while we may never show session created + this prevents us from showing invalid state messages
    // in session created when session is not ready. Instantiate view models lazily (and ensure cleared when leaving)?
    // or maybe use only one view model for everything?
    init(viewModel: HomeViewModel, sessionViewModel: SessionViewModel, meetingCreatedViewModel: MeetingCreatedViewModel,
         meetingJoinedViewModel: MeetingJoinedViewModel, meetingViewModel: MeetingViewModel) {
        self.viewModel = viewModel
        self.sessionViewModel = sessionViewModel
        self.meetingCreatedViewModel = meetingCreatedViewModel
        self.meetingJoinedViewModel = meetingJoinedViewModel
        self.meetingViewModel = meetingViewModel
    }

    var body: some View {
        viewForState(state: viewModel.state)
    }

    private func viewForState(state: HomeViewState) -> some View {
        log.d("Updating home view for state: \(state)", .ui)
        switch state {
        case .noMeeting:
            return AnyView(noMeetingView())
        case .meetingCreated:
            return AnyView(MeetingCreatedView(viewModel: meetingCreatedViewModel))
        case .meetingJoined:
            return AnyView(MeetingJoinedView(viewModel: meetingJoinedViewModel))
        case .meetingActive:
            return AnyView(meetingActiveView())
        }
    }

    private func noMeetingView() -> some View {
        SessionView(viewModel: sessionViewModel)
    }

    private func meetingActiveView() -> some View {
        MeetingView(viewModel: meetingViewModel)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let sessionService = NoopCurrentSessionService()
        let uiNotifier = NoopUINotifier()
        let clipboard = NoopClipboard()
        let bleManager = BleManagerImpl(peripheral: BlePeripheralNoop(), central: BleCentralNoop())

        HomeView(viewModel: HomeViewModel(
                    sessionService: NoopCurrentSessionService(),
                    uiNotifier: NoopUINotifier()),
                 sessionViewModel: SessionViewModel(sessionService: sessionService,
                                                    clipboard: clipboard,
                                                    uiNotifier: uiNotifier),
                 meetingCreatedViewModel: MeetingCreatedViewModel(sessionService: sessionService, clipboard: clipboard,
                                                                  uiNotifier: uiNotifier),
                 meetingJoinedViewModel: MeetingJoinedViewModel(sessionService: sessionService, clipboard: clipboard,
                                                                uiNotifier: uiNotifier),
                 meetingViewModel: MeetingViewModel(bleManager: bleManager)
        )
    }
}
