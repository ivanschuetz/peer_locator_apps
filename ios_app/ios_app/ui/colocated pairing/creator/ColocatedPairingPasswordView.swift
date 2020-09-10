import Foundation
import SwiftUI

struct ColocatedPairingPasswordView: View {
    @ObservedObject private var viewModel: ColocatedPairingPasswordViewModel

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.colocatedPassword()
    }

    var body: some View {
        VStack {
            Text(viewModel.password)
            Text("Tell your peer to read this QR code")
        }
    }
}
