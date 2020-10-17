import SwiftUI

struct MeetingCreatedView: View {
    @ObservedObject var viewModel: MeetingCreatedViewModel
    private var viewModelProvider: ViewModelProvider

    @State private var showShareSheet = false
    @State private var showConfirmDeleteAlert = false

    @Environment(\.presentationMode) var presentation

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.meetingCreated()
        self.viewModelProvider = viewModelProvider
    }

    var body: some View {
        ZStack {
            VStack {
                Text("Send this link to your peer:")
                    .padding(.bottom, 30)

                Text(viewModel.linkText)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.blue)
                    .padding(.bottom, 20)
                    .onTapGesture {
                        viewModel.onCopyLinkTap()
                    }
                HStack {
                    Button(action: {
                        viewModel.onCopyLinkTap()
//                    }) { Image(systemName: "arrow.up.doc").styleIconDefault() }
                    }) { Image(systemName: "square.on.square").styleIconDefault() }
                    .padding(.trailing, 30)

                    Button(action: {
                        showShareSheet = true
                    }) { Image(systemName: "square.and.arrow.up").styleIconDefault() }
                }

                .padding(.bottom, 30)
                // TODO(next) remove share button
                // TODO(frozen until share button reenabled) don't allow to show modal if there's no link
                .sheet(isPresented: $showShareSheet) {
                    // TODO(frozen until share button reenabled) no optional (viewModel.link)
                    // TODO(frozen until share button reenabled) sometimes it doesn't work. maybe disable for now, it's confusing anyway with copy button.
                    ShareSheet(activityItems: [viewModel.linkUrl])
                }
                .padding(.bottom, 10)
                Text("Waiting for your peer to join")
                    .padding(.bottom, 10)
                // For dev
//                ActionButton("Update status") {
//                    viewModel.onUpdateStatusTap()
//                }
//                .padding(.bottom, 10)
                ActionDeleteButton("Delete session") {
                    showConfirmDeleteAlert = true
                }
            }
            .defaultOuterHPadding()

            if viewModel.showLoading {
                ProgressOverlay()
            }
        }
        .alert(isPresented: $showConfirmDeleteAlert) {
            Alert(title: Text("Delete session"),
                  message: Text("Are you sure?"),
                  primaryButton: .default(Text("Yes")) {
                    if viewModel.onDeleteSessionTap() {
                        // Doesn't work when environment is in view model.
                        // this could be implemented reactively but this seems ok for now.
                        log.d("Navigating back from created view", .ui)
                        presentation.wrappedValue.dismiss()
                    }
                  },
                  secondaryButton: .default(Text("Cancel"))
            )
        }
        .navigationBarTitle(Text("Session created!"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(trailing: Button(action: { [weak viewModel] in
            viewModel?.onSettingsButtonTap()
        }) { SettingsImage() })
        .sheet(isPresented: $viewModel.showSettingsModal) {
            SettingsView(viewModelProvider: viewModelProvider)
        }
    }
}

struct MeetingCreatedView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingCreatedView(viewModelProvider: DummyViewModelProvider())
    }
}
