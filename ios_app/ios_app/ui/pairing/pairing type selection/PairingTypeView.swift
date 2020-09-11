import SwiftUI
import Combine

struct PairingTypeView: View {
    @ObservedObject private var viewModel: PairingTypeViewModel
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
        PairingTypeView(viewModelProvider: DummyViewModelProvider())
    }
}
