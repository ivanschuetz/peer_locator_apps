import SwiftUI
import Combine

struct RootView: View {
    @ObservedObject private var viewModel: RootViewModel

    private let viewModelProvider: ViewModelProvider

    // TODO review states+view models: view models are eagerly instantiated, so we've e.g. a session created
    // view model active while we may never show session created + this prevents us from showing invalid state messages
    // in session created when session is not ready. Instantiate view models lazily (and ensure cleared when leaving)?
    // or maybe use only one view model for everything?
    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.root()
        self.viewModelProvider = viewModelProvider
    }

    var body: some View {
        viewForState(state: viewModel.state)
            .sheet(isPresented: $viewModel.showSettingsModal) {
                SettingsView(viewModel: viewModelProvider.settings())
            }
    }

    private func viewForState(state: RootViewState) -> some View {
        log.d("Updating root view for state: \(state)", .ui)
        switch state {
        case .noMeeting:
            return AnyView(noMeetingView())
        case .meetingActive:
            return AnyView(meetingActiveView())
        }
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

class NoopSettingsShower: SettingsShower {
    lazy var showing: AnyPublisher<Bool, Never> = Just(false).eraseToAnyPublisher()
    func show() {}
    func hide() {}
}

class NoopBleEnabledService: BleEnabledService {
    var bleEnabled: AnyPublisher<Bool, Never> = Just(true).eraseToAnyPublisher()
    func enable() {}
}

class NoopRemoteSessionManager: RemoteSessionManager {
    func create() {}
    func join(sessionId: SessionId) {}
    func refresh() {}
}
