import Foundation
import SwiftUI

struct RemotePairingRoleSelectionView: View {
    @ObservedObject private var viewModel: RemotePairingRoleSelectionViewModel

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.remotePairingRole()
    }

    var body: some View {
        VStack {
            Button("Create session", action: {
                viewModel.onCreateSessionTap()
            })
            padding(.bottom, 30)
            Button("Join session", action: {
                viewModel.onJoinSessionTap()
            })
        }
    }
}
