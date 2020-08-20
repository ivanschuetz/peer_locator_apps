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
            Text(viewModel.createdSessionLink)
            TextField("", text: $viewModel.sessionId)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .background(Color.green)
            Button("Join session", action: {
                viewModel.joinSession()
            })
            Text(viewModel.sessionStartedMessage)
        }
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionView(viewModel: SessionViewModel(sessionService: NoopSessionService()))
    }
}

class NoopSessionService: SessionService {

    func createSession() -> Result<SessionLink, ServicesError> {
        .success(SessionLink(value: "123"))
    }

    func joinSession(sessionId: SessionId) -> Result<SessionReady, ServicesError> {
        .success(.no)
    }

    func refreshSessionData() -> Result<SessionReady, ServicesError> {
        .success(.no)
    }
}
