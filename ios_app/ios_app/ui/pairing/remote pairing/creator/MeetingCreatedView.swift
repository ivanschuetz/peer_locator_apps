import SwiftUI

struct MeetingCreatedView: View {
    @ObservedObject var viewModel: MeetingCreatedViewModel

    @State private var showShareSheet = false

    @Environment(\.presentationMode) var presentation

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.meetingCreated()
    }

    var body: some View {
        ZStack {
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
                .padding(.bottom, 10)
                ActionButton("Update status") {
                    viewModel.onUpdateStatusTap()
                }
                .padding(.bottom, 10)
                ActionDeleteButton("Delete session") {
                    // Doesn't work when environment is in view model.
                    // this could be implemented reactively but this seems ok for now.
                    if viewModel.onDeleteSessionTap() {
                        log.d("Navigating back from created view", .ui)
                        presentation.wrappedValue.dismiss()
                    }
                }
            }
            .defaultOuterHPadding()

            if viewModel.showLoading {
                ProgressOverlay()
            }
        }

        .navigationBarTitle(Text("Session created!"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(trailing: Button(action: { [weak viewModel] in
            viewModel?.onSettingsButtonTap()
        }) { SettingsImage() })
    }
}

struct MeetingCreatedView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingCreatedView(viewModelProvider: DummyViewModelProvider())
    }
}
