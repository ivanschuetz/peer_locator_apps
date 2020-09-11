import SwiftUI

// Only for development: in production we join only via deeplink

struct RemotePairingJoinerView: View {
    @ObservedObject var viewModel: RemotePairingJoinerViewModel
    private let viewModelProvider: ViewModelProvider

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.meetingJoiner()
        self.viewModelProvider = viewModelProvider
    }

    var body: some View {
        VStack {
            HStack {
                TextField("", text: $viewModel.sessionLinkInput)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    .background(Color.green)
                Button("Paste", action: {
                    viewModel.onPasteLinkTap()
                })
            }
            .padding(.bottom, 30)
            Button("Join session", action: {
                viewModel.joinSession()
            })
            NavigationLink(destination: Lazy(MeetingJoinedView(viewModelProvider: viewModelProvider)),
                           isActive: $viewModel.navigateToJoinedView) {
               Spacer().fixedSize()
            }
        }
        .navigationBarTitle(Text("Join session"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(trailing: Button(action: {
            viewModel.onSettingsButtonTap()
        }) { SettingsImage() })
    }
}

struct RemotePairingWaitingView_Previews: PreviewProvider {
    static var previews: some View {
        RemotePairingJoinerView(viewModelProvider: DummyViewModelProvider())
    }
}
