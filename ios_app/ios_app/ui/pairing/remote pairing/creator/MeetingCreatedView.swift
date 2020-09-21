import SwiftUI

struct MeetingCreatedView: View {
    @ObservedObject var viewModel: MeetingCreatedViewModel

    @State private var showShareSheet = false

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.meetingCreated()
    }

    var body: some View {
        VStack {
            Text("Send this link to your peer:")
                .padding(.bottom, 30)

            Text(viewModel.linkText)
                .foregroundColor(Color.blue)
                .padding(.bottom, 20)

            HStack {
                Button(action: {
                    viewModel.onCopyLinkTap()
                }) { Image(systemName: "arrow.up.doc").styleIconDefault() }
                .padding(.trailing, 30)

                Button(action: {
                    showShareSheet = true
                }) { Image(systemName: "square.and.arrow.up").styleIconDefault() }
            }

            .padding(.bottom, 30)
            // TODO don't allow to show modal if there's no link
            .sheet(isPresented: $showShareSheet) {
                // TODO no optional (viewModel.link)
                ShareSheet(activityItems: [viewModel.linkUrl])
            }
            ActionButton("Check session status") {
                viewModel.updateSession()
            }
        }
        .defaultOuterHPadding()

        .navigationBarTitle(Text("Session created!"), displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            viewModel.onSettingsButtonTap()
        }) { SettingsImage() })
    }
}

struct MeetingCreatedView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingCreatedView(viewModelProvider: DummyViewModelProvider())
    }
}
