import SwiftUI
import Combine

struct SessionView: View {
    @ObservedObject private var viewModel: SessionViewModel

    init(viewModel: SessionViewModel) {
        self.viewModel = viewModel
    }

    // TODO show a note somewhere that there can be only 2 participants
    // maybe a notification after creating the session
    // "your meeting was created! link: x, note that max. 2 devices can register"

    var body: some View {
        VStack {
            Button("Create session", action: {
                viewModel.createSession()
            })
            .padding(.bottom, 30)
            HStack {
                Text(viewModel.createdSessionLink)
                Button("Copy", action: {
                    viewModel.onCopyLinkTap()
                })
            }
            .padding(.bottom, 30)
            HStack {
                TextField("", text: $viewModel.sessionLinkInput)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    .background(Color.green)
                Button("Paste", action: {
                    viewModel.onPasteLinkTap()
                })
            }
            .padding(.bottom, 30)
            Button("Join session", action: {
                viewModel.joinSession()
            })
            .padding(.bottom, 30)
            Text(viewModel.sessionStartedMessage)
            Button("Activate session", action: {
                viewModel.activateSession()
            })
        }
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionView(viewModel: SessionViewModel(sessionService: NoopCurrentSessionService(),
                                                p2pService: P2pServiceImpl(bleManager: BleManagerNoop()),
                                                clipboard: NoopClipboard(),
                                                uiNotifier: NoopUINotifier()))
    }
}

class NoopUINotifier: UINotifier {
    func show(_ notification: UINotification) {}
}

class NoopSessionService: SessionService {

    func createSession() -> Result<SharedSessionData, ServicesError> {
        .success(SharedSessionData(id: SessionId(value: "123"), isReady: .no, createdByMe: true))
    }

    func joinSession(link: SessionLink) -> Result<SharedSessionData, ServicesError> {
        .success(SharedSessionData(id: try! link.extractSessionId().get(), isReady: .no, createdByMe: false))
    }

    func refreshSessionData() -> Result<SharedSessionData, ServicesError> {
        .success(SharedSessionData(id: SessionId(value: "123"), isReady: .no, createdByMe: false))
    }

    func currentSession() -> Result<SharedSessionData?, ServicesError> {
        .success(nil)
    }

    func currentSessionParticipants() -> Result<Participants?, ServicesError> {
        .success(nil)
    }
}

class NoopCurrentSessionService: CurrentSessionService {
    var session: AnyPublisher<Result<SharedSessionData?, ServicesError>, Never> = Just(.success(nil))
        .eraseToAnyPublisher()

    func create() {}

    func join(link: SessionLink) {}

    func refresh() {}
}

class NoopClipboard: Clipboard {
    func getFromClipboard() -> String { "" }
    func putInClipboard(text: String) {}
}
