import SwiftUI
import Combine

struct PairingTypeView: View {
    @ObservedObject private var viewModel: PairingTypeViewModel
    private let viewModelProvider: ViewModelProvider

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.session()
        self.viewModelProvider = viewModelProvider
    }

    // TODO(pmvp) show a note somewhere that there can be only 2 peers
    // maybe a notification after creating the session
    // "your meeting was created! link: x, note that max. 2 devices can register"

    func destination() -> some View {
        Text("")
    }

    var body: some View {
        VStack {
            Text("Are you and your peer in the same location now?")
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)
            // TODO(pmvp) question mark with expl: "same location: <100m appart"
            ActionButton("Yes") {
                viewModel.onColocatedTap()
            }
            .padding(.bottom, buttonsVerticalSpacing)
            ActionButton("No") {
                viewModel.onRemoteTap()
            }
            NavigationLink(destination: Lazy(destinationView(destination: viewModel.destination)),
                           isActive: $viewModel.navigationActive) {
               Spacer().fixedSize()
            }
        }
        .defaultOuterHPadding()
        .navigationBarTitle(Text("Session"), displayMode: .inline)
        .navigationBarItems(trailing: Button(action: { [weak viewModel] in
            viewModel?.onSettingsButtonTap()
        }) { SettingsImage() })
        .sheet(isPresented: $viewModel.showSettingsModal) {
            SettingsView(viewModelProvider: viewModelProvider)
        }
    }

    private func destinationView(destination: PairingTypeDestination) -> some View {
        switch destination {
        case .colocated: return AnyView(ColocatedPairingRoleSelectionView(viewModelProvider: viewModelProvider))
        case .remote: return AnyView(RemotePairingRoleSelectionView(viewModelProvider: viewModelProvider))
        case .none: return AnyView(Spacer().fixedSize()) // not used
        }
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        PairingTypeView(viewModelProvider: DummyViewModelProvider())
    }
}
