import SwiftUI
import Combine

struct SessionView: View {
    @ObservedObject private var viewModel: SessionViewModel
    private let viewModelProvider: ViewModelProvider

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.session()
        self.viewModelProvider = viewModelProvider
    }

    // TODO show a note somewhere that there can be only 2 participants
    // maybe a notification after creating the session
    // "your meeting was created! link: x, note that max. 2 devices can register"

    func destination() -> some View {
        Text("")
    }

    var body: some View {
        VStack {
            Text("Are you and your peer in the same location now?")
                .padding(.bottom, 30)
            // TODO question mark with expl: "same location: <100m appart"
            NavigationLink(destination: Lazy(ColocatedPairingRoleSelectionView(viewModelProvider: viewModelProvider))) {
                Text("Yes")
            }
            .padding(.bottom, 30)
            NavigationLink(destination: Lazy(RemotePairingRoleSelectionView(viewModelProvider: viewModelProvider))) {
                Text("No")
            }
//            Button("Create session", action: {
//                viewModel.createSession()
//            })
//            .padding(.bottom, 30)
//            HStack {
//                Text(viewModel.createdSessionLink).background(Color.red)
//                Button("Copy", action: {
//                    viewModel.onCopyLinkTap()
//                })
//            }
//            .padding(.bottom, 30)
//            HStack {
//                TextField("", text: $viewModel.sessionLinkInput)
//                    .multilineTextAlignment(.center)
//                    .padding(.top, 20)
//                    .padding(.bottom, 20)
//                    .background(Color.green)
//                Button("Paste", action: {
//                    viewModel.onPasteLinkTap()
//                })
//            }
//            .padding(.bottom, 30)
//            Button("Join session", action: {
//                viewModel.joinSession()
//            })
        }
        .navigationBarTitle(Text("Session"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(trailing: Button(action: {
            viewModel.onSettingsButtonTap()
        }) { SettingsImage() })
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionView(viewModelProvider: DummyViewModelProvider())
    }
}
