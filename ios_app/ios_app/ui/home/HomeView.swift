import SwiftUI
import Combine

struct HomeView: View {
    @ObservedObject private var viewModel: HomeViewModel

    private let sessionViewModel: SessionViewModel
    private let meetingCreatedViewModel: MeetingCreatedViewModel
    private let meetingJoinedViewModel: MeetingJoinedViewModel
    private let meetingViewModel: MeetingViewModel
    private let settingsViewModel: SettingsViewModel

    // TODO review states+view models: view models are eagerly instantiated, so we've e.g. a session created
    // view model active while we may never show session created + this prevents us from showing invalid state messages
    // in session created when session is not ready. Instantiate view models lazily (and ensure cleared when leaving)?
    // or maybe use only one view model for everything?
    init(viewModel: HomeViewModel, sessionViewModel: SessionViewModel, meetingCreatedViewModel: MeetingCreatedViewModel,
         meetingJoinedViewModel: MeetingJoinedViewModel, meetingViewModel: MeetingViewModel,
         settingsViewModel: SettingsViewModel) {
        self.viewModel = viewModel
        self.sessionViewModel = sessionViewModel
        self.meetingCreatedViewModel = meetingCreatedViewModel
        self.meetingJoinedViewModel = meetingJoinedViewModel
        self.meetingViewModel = meetingViewModel
        self.settingsViewModel = settingsViewModel
    }

    var body: some View {
        viewForState(state: viewModel.state)
            .sheet(isPresented: $viewModel.showSettingsModal) {
                SettingsView(viewModel: settingsViewModel)
            }
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
        let peerService = PeerServiceImpl(nearby: NearbyNoop(), bleManager: bleManager, bleIdService: BleIdServiceNoop())

        HomeView(viewModel: HomeViewModel(
                    sessionService: NoopCurrentSessionService(),
                    uiNotifier: NoopUINotifier(),
                    settingsShower: NoopSettingsShower()),
                 sessionViewModel: SessionViewModel(sessionService: sessionService,
                                                    clipboard: clipboard,
                                                    uiNotifier: uiNotifier,
                                                    settingsShower: NoopSettingsShower()),
                 meetingCreatedViewModel: MeetingCreatedViewModel(sessionService: sessionService, clipboard: clipboard, uiNotifier: uiNotifier, settingsShower: NoopSettingsShower()),
                 meetingJoinedViewModel: MeetingJoinedViewModel(sessionService: sessionService, clipboard: clipboard, uiNotifier: uiNotifier, settingsShower: NoopSettingsShower()),
                 meetingViewModel: MeetingViewModel(peerService: peerService, sessionService: sessionService, settingsShower: NoopSettingsShower()),
                 settingsViewModel: SettingsViewModel()
        )
    }
}

class NoopSettingsShower: SettingsShower {
    lazy var showing: AnyPublisher<Bool, Never> = Just(false).eraseToAnyPublisher()
    func show() {}
    func hide() {}
}
