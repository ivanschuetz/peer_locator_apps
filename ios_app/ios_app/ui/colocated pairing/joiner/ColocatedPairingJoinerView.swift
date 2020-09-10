import Foundation
import SwiftUI

struct ColocatedPairingJoinerView: View {
    @ObservedObject private var viewModel: ColocatedPairingJoinerViewModel

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.colocatedPairingJoiner()
    }

    var body: some View {
        VStack {
            Text("Open the camera app and scan your peer's QR code")
            // TODO exit options/failure handling: e.g. "peer isn't showing a qr code"
        }
    }
}
