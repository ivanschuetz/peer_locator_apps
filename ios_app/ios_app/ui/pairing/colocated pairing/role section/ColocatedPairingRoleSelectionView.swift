import Foundation
import SwiftUI

struct ColocatedPairingRoleSelectionView: View {
    @ObservedObject private var viewModel: ColocatedPairingRoleSelectionViewModel
    private let viewModelProvider: ViewModelProvider

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.colocatedPairingRole()
        self.viewModelProvider = viewModelProvider
    }

    var body: some View {
        VStack {
            Button("Create session") {
                viewModel.onCreateSessionTap()
            }
            .styleAction()
            .padding(.bottom, buttonsVerticalSpacing)
            Button("Join session") {
                viewModel.onJoinSessionTap()
            }
            .styleAction()
            NavigationLink(destination: Lazy(destinationView(destination: viewModel.destination)),
                           isActive: $viewModel.navigationActive) {
               Spacer().fixedSize()
            }
        }
        .navigationBarTitle(Text("Select role"), displayMode: .inline)
        .navigationBarItems(trailing: Button(action: { [weak viewModel] in
            viewModel?.onSettingsButtonTap()
        }) { SettingsImage() })
    }

    private func destinationView(destination: ColocatedPairingRoleDestination) -> some View {
        switch destination {
        case .create: return AnyView(ColocatedPairingPasswordView(viewModelProvider: viewModelProvider))
        case .join: return AnyView(MeetingCreatedView(viewModelProvider: viewModelProvider))
        case .none: return AnyView(Spacer().fixedSize()) // not used
        }
    }
}
