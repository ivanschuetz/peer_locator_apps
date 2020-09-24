import Foundation
import SwiftUI
import Combine

class ColocatedPairingJoinerViewModel: ObservableObject {
    private let passwordService: ColocatedPairingPasswordService
    private let uiNotifier: UINotifier

    @Published var showScanner: Bool = false

    // [investigating camera bug] -> sometimes (especially on ipad?) the first time we open the camera
    // it closes immediately. An initial print revealed that the binding was firing multiple times.
    // couldn't reproduce (tried 3-4 times) after adding logs. TODO test again.

    init(passwordService: ColocatedPairingPasswordService, uiNotifier: UINotifier) {
        self.passwordService = passwordService
        self.uiNotifier = uiNotifier

        log.w("[investigating camera bug] creating view model. showscanner: \(showScanner)")
        // for quick testing: simulate having read the password
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            passwordService.processPassword(ColocatedPeeringPassword(value: "123"))
//        }
    }

    func onStartCameraTap() {
        showScanner = true
        log.w("[investigating camera bug] did showscanner to true: \(showScanner)")
    }
    
    func onScanPasswordResult(_ result: Result<String, ServicesError>) {
        showScanner = false
        log.w("[investigating camera bug] did showscanner to false: \(showScanner)")

        switch result {
        case .success(let password):
            passwordService.processPassword(ColocatedPeeringPassword(value: password))
        case .failure(let error):
            log.e("QR code scanning failed: \(error)", .ui)
            uiNotifier.show(.error("Scanning failed."))
        }
    }

    deinit {
        log.d("View model deinit", .ui)
    }
}
