import Foundation
import Combine

protocol NearbySessionCoordinator {}

class NearbySessionCoordinatorImpl: NearbySessionCoordinator {
    private let bleManager: BleManager
    private let bleIdService: BleIdService

    private var sendNearbyTokenCancellable: Cancellable?
    private var receivedNearbyTokenCancellable: Cancellable?

    init(bleManager: BleManager, bleIdService: BleIdService, nearby: Nearby, nearbyTokenSender: NearbyTokenSender,
         nearbyTokenReceiver: NearbyTokenReceiver) {
        self.bleManager = bleManager
        self.bleIdService = bleIdService

        // Idea is to send the nearby token (i.e. initiate the session) when
        // 1) the devices come in ble range (to be tested whether this doesn't trigger nearby timeout/invalidation)
        // 2) the nearby connection was invalidated (e.g. due to timeout).
        // note that 1) and 2) could be simultaneous (we start app in nearby range)
        // TODO check behaviour in this case: does the "old" session get properly invalidated and new one works?
        // TODO review and test in general: this is more of a quick placeholder implementation.

        let validatedBlePeer = bleManager.discovered
            .map { bleIdService.validate(bleId: $0.id) }
            .removeDuplicates()
            .filter { $0 }
            
        let sessionStopped = nearby.sessionState
            .removeDuplicates()
            .filter { $0 == .removed }

        sendNearbyTokenCancellable = validatedBlePeer.combineLatest(sessionStopped)
            .sink { _, _ in
                if let token = nearby.token() {
                    log.i("Sending nearby discovery token to peer: \(token)", .nearby)
                    // TODO sign/verify the token
                    nearbyTokenSender.sendDiscoveryToken(token: token)
                } else {
                    log.e("Critical: nearby token returned nil. Can't send discovery token.", .nearby)
                }
            }

        receivedNearbyTokenCancellable = nearbyTokenReceiver.token.sink { data in
            let token = NearbyToken(data: data)
            nearby.start(peerToken: token)
        }
    }
}
