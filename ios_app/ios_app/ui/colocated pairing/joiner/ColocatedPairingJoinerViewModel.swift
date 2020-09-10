import Foundation
import SwiftUI
import Combine

class ColocatedPairingJoinerViewModel: ObservableObject {

    init(passwordService: ColocatedPairingPasswordService) {
        // simulate having read the password TODO replace
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            passwordService.processPassword(ColocatedPeeringPassword(value: "123"))
        }
    }
}
