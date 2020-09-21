import SwiftUI

struct MeetingJoinedView: View {
    private let viewModel: MeetingJoinedViewModel
    
    @Environment(\.presentationMode) var presentation

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.meetingJoined()
    }

    var body: some View {
        VStack {
            Text("Joined! Waiting for peer to acknowledge.")
                .padding(.bottom, 30)
            ActionButton("Check status") {
                viewModel.updateSession()
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
