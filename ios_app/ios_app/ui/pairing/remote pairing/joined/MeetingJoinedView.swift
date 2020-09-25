import SwiftUI

struct MeetingJoinedView: View {
    private let viewModel: MeetingJoinedViewModel
    
    @State private var showConfirmDeleteAlert = false

    @Environment(\.presentationMode) var presentation

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.meetingJoined()
    }

    var body: some View {
        VStack {
            Text("Joined! Waiting for peer to acknowledge.")
                .padding(.bottom, 30)
            // For dev
//            ActionButton("Check status") {
//                viewModel.updateSession()
//            }
            .padding(.bottom, 10)
            ActionDeleteButton("Delete session") {
                showConfirmDeleteAlert = true
            }
            .alert(isPresented: $showConfirmDeleteAlert) {
                Alert(title: Text("Delete session"),
                      message: Text("Are you sure? You and your peer will have pair again."),
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
            .navigationBarTitle(Text("Session joined!"), displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(trailing: Button(action: { [weak viewModel] in
                viewModel?.onSettingsButtonTap()
            }) { SettingsImage() })
        }
    }
}

struct MeetingJoinedView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingJoinedView(viewModelProvider: DummyViewModelProvider())
    }
}
