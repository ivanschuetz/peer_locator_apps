import SwiftUI

struct MeetingJoinedView: View {
    private let viewModel: MeetingJoinedViewModel

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.meetingJoined()
    }

    var body: some View {
        VStack {
            Text("Joined! Waiting for peer to acknowledge.")
                .padding(.bottom, 30)
            Button("Check session status", action: {
                viewModel.updateSession()
            })
            .navigationBarTitle(Text("Session joined!"), displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(trailing: Button(action: {
                viewModel.onSettingsButtonTap()
            }) { SettingsImage() })
        }
    }
}

struct MeetingJoinedView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingJoinedView(viewModelProvider: DummyViewModelProvider())
    }
}
