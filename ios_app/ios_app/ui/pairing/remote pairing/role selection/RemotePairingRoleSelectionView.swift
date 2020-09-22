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
        ZStack {
            VStack {
                ActionButton("Create session") {
                    viewModel.onCreateSessionTap()
                }
                .disabled(viewModel.showLoading)
                .padding(.bottom, buttonsVerticalSpacing)
                ActionButton("Join session") {
                    viewModel.onJoinSessionTap()
                }.disabled(viewModel.showLoading)
                NavigationLink(destination: Lazy(destinationView(destination: viewModel.destination)),
                               isActive: $viewModel.navigationActive) {
                   Spacer().fixedSize()
                }
            }
            if viewModel.showLoading {
                ProgressOverlay()
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
