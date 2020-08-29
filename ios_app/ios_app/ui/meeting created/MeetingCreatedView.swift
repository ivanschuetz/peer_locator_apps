import SwiftUI

struct MeetingCreatedView: View {
    @ObservedObject var viewModel: MeetingCreatedViewModel

    @State private var showShareSheet = false

    init(viewModel: MeetingCreatedViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Text("Meeting link")
            .padding(.bottom, 30)
        HStack {
            Text(viewModel.linkText)
            Button("Copy", action: {
                viewModel.onCopyLinkTap()
            })
        }
        .padding(.bottom, 30)
        TextField(viewModel.linkText, text: $viewModel.sessionLinkInput)
            .multilineTextAlignment(.center)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .background(Color.yellow)
        Text("Send this link to your peer using a medium of your choice")
            .padding(.bottom, 30)
        Button("Share", action: {
            showShareSheet = true
        })
        .padding(.bottom, 30)
        // TODO don't allow to show modal if there's no link
        .sheet(isPresented: $showShareSheet) {
            // TODO no optional (viewModel.link)
            ShareSheet(activityItems: [viewModel.link!])
        }
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
