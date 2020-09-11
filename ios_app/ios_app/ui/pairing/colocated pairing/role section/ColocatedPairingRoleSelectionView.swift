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
            NavigationLink(destination: Lazy(ColocatedPairingPasswordView(viewModelProvider: viewModelProvider))) {
                Text("Create session")
            }.simultaneousGesture(TapGesture().onEnded({
                viewModel.onNavigateToCreateSession()
            }))
            .padding(.bottom, 30)
            NavigationLink(destination: Lazy(ColocatedPairingJoinerView(viewModelProvider: viewModelProvider))) {
                Text("Join session")
            }.simultaneousGesture(TapGesture().onEnded({
                viewModel.onNavigateToJoinSession()
            }))
        }
    }
}
