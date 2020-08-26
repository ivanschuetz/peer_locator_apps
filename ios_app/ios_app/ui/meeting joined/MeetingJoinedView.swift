import SwiftUI

struct MeetingJoinedView: View {
    private let viewModel: MeetingJoinedViewModel

    init(viewModel: MeetingJoinedViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Text("Joined! Waiting for peer to acknowledge.")
            .padding(.bottom, 30)
        Button("Check session status", action: {
            viewModel.updateSession()
        })
    }
}

struct MeetingJoinedView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingJoinedView(viewModel: MeetingJoinedViewModel(sessionService: NoopCurrentSessionService(),
                                                            clipboard: NoopClipboard(), uiNotifier: NoopUINotifier()))
    }
}
