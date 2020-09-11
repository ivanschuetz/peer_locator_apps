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
            Button("Create session", action: {
                viewModel.onCreateSessionTap()
            })
            // this crashes. Probably SwiftUI bug. TODO revisit in new xcode versions
//            padding(.bottom, 30)
            NavigationLink(destination: Lazy(RemotePairingJoinerView(viewModelProvider: viewModelProvider))) {
                    Text("Join session")
            }
            NavigationLink(destination: Lazy(MeetingCreatedView(viewModelProvider: viewModelProvider)),
                           isActive: $viewModel.navigateToCreateView) {
               Spacer().fixedSize()
            }
        }
    }
}
