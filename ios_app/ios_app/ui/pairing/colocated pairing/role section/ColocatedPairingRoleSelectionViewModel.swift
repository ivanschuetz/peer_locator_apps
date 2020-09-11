import Foundation
import SwiftUI

class ColocatedPairingRoleSelectionViewModel: ObservableObject {
    private let sessionService: ColocatedSessionService

    init(sessionService: ColocatedSessionService) {
        self.sessionService = sessionService
    }

    func onNavigateToCreateSession() {
        sessionService.startPairingSession()
    }

    func onNavigateToJoinSession() {
        sessionService.startPairingSession()
    }
}
