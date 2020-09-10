import Foundation
import SwiftUI
import CoreImage.CIFilterBuiltins

struct ColocatedPairingPasswordView: View {
    @ObservedObject private var viewModel: ColocatedPairingPasswordViewModel

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.colocatedPassword()
    }

    var body: some View {
        VStack {
            Image(uiImage: generateQRCode(from: viewModel.password))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
            Text(viewModel.password)
            Text("Tell your peer to read this QR code")
        }
    }

    private func generateQRCode(from string: String) -> UIImage {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
