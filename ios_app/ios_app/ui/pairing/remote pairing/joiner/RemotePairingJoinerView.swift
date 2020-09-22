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
        ZStack {
            VStack {
                Text("Open the link sent by your peer, or insert it below and click \"Join session\"")
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 30)
                HStack {
                    TextField("", text: $viewModel.sessionLinkInput)
                        .styleDefault()
                        .truncationMode(.middle)
                        .padding(.trailing, 10)

                    Button(action: {
                        viewModel.onPasteLinkTap()
    //                }) { Image(systemName: "doc.on.clipboard")
                    }) { Image(systemName: "arrow.down.doc").styleIconDefault() }
                }
                .padding(.bottom, 30)

                Button(action: {
                    viewModel.joinSession()
                }) { Text("Join session").styleButton() }
                NavigationLink(destination: Lazy(MeetingJoinedView(viewModelProvider: viewModelProvider)),
                               isActive: $viewModel.navigateToJoinedView) {
                   Spacer().fixedSize()
                }
            }
            .defaultOuterHPadding()
            if viewModel.showLoading {
                ProgressOverlay()
            }
        }
        .navigationBarTitle(Text("Join session"), displayMode: .inline)
        .navigationBarItems(trailing: Button(action: { [weak viewModel] in
            viewModel?.onSettingsButtonTap()
        }) { SettingsImage() })
    }
}

struct RemotePairingWaitingView_Previews: PreviewProvider {
    static var previews: some View {
        RemotePairingJoinerView(viewModelProvider: DummyViewModelProvider())
    }
}
