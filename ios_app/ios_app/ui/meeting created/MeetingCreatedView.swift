import SwiftUI

struct MeetingCreatedView: View {
    @ObservedObject var viewModel: MeetingCreatedViewModel

    init(viewModel: MeetingCreatedViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Text("Meeting link")
            .padding(.bottom, 30)
        HStack {
            Text(viewModel.link)
            Button("Copy", action: {
                viewModel.onCopyLinkTap()
            })
        }
        .padding(.bottom, 30)
        TextField(viewModel.link, text: $viewModel.sessionLinkInput)
            .multilineTextAlignment(.center)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .background(Color.yellow)
        Text("Send this link to your peer using a medium of your choice")
            .padding(.bottom, 30)
        Button("Check session status", action: {
            viewModel.updateSession()
        })
    }
}

struct MeetingCreatedView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingCreatedView(viewModel: MeetingCreatedViewModel(sessionService: NoopCurrentSessionService(),
                                                              clipboard: NoopClipboard(),
                                                              uiNotifier: NoopUINotifier()))
    }
}
