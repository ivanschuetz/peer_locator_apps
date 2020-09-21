import Foundation
import SwiftUI

struct RemotePairingRoleSelectionView: View {
    @ObservedObject private var viewModel: RemotePairingRoleSelectionViewModel
    private let viewModelProvider: ViewModelProvider

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.remotePairingRole()
        self.viewModelProvider = viewModelProvider
    }

    var body: some View {
        VStack {
            ActionButton("Create session") {
                viewModel.onCreateSessionTap()
            }
            .padding(.bottom, buttonsVerticalSpacing)
            // this crashes. Probably SwiftUI bug. TODO revisit in new xcode versions
//            padding(.bottom, 30)
            ActionButton("Join session") {
                viewModel.onJoinSessionTap()
            }
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

    private func destinationView(destination: RemotePairingRoleDestination) -> some View {
        switch destination {
        case .create: return AnyView(MeetingCreatedView(viewModelProvider: viewModelProvider))
        case .join: return AnyView(RemotePairingJoinerView(viewModelProvider: viewModelProvider))
        case .none: return AnyView(Spacer().fixedSize()) // not used
        }
    }
}
