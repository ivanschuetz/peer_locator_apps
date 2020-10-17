import Foundation
import SwiftUI
import CodeScanner

struct ColocatedPairingJoinerView: View {
    @ObservedObject private var viewModel: ColocatedPairingJoinerViewModel

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.colocatedPairingJoiner()
    }

    var body: some View {
        log.w("[investigating camera bug] view. showscanner: \($viewModel.showScanner)")

        return VStack {
            ActionButton("Open camera") {
                viewModel.onStartCameraTap()
            }
            Text("Open the camera to read your peer's QR code")

            // TODO(pmvp) exit options/failure handling: e.g. "peer isn't showing a qr code"
        }
        .sheet(isPresented: $viewModel.showScanner) {
            CodeScannerView(codeTypes: [.qr],
                            completion: handleScan)
        }
    }

    func handleScan(result: Result<String, CodeScannerView.ScanError>) {
        log.w("[investigating camera bug] in handle scan")
        viewModel.onScanPasswordResult(result.mapError {
            .general("QR code scanner error: \($0)")
        })
    }
}
