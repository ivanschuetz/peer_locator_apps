import Foundation
import SwiftUI

class ColocatedPairingPasswordViewModel: ObservableObject {
    let password: String

    init(sessionService: ColocatedSessionService) {
        password = sessionService.generatePassword().value
    }

    deinit {
        log.d("View model deinit", .ui)
    }
}
