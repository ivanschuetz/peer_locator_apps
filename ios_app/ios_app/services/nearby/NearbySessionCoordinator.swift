import Foundation
import Combine

protocol NearbySessionCoordinator {}

class NearbySessionCoordinatorImpl: NearbySessionCoordinator {
    private var sendNearbyTokenCancellable: Cancellable?
    private var receivedNearbyTokenCancellable: Cancellable?

    init(nearby: Nearby, nearbyPairing: NearbyPairing, uiNotifier: UINotifier, sessionStore: SessionStore,
         tokenProcessor: NearbyTokenProcessor, validDeviceService: DetectedBleDeviceFilterService,
         appEvents: AppEvents, tokenSender: NearbyTokenSender) {

        // Idea is to send the nearby token (i.e. initiate the session) when
        // 1) the devices come in ble range (to be tested whether this doesn't trigger nearby timeout/invalidation)
        // 2) the nearby connection was invalidated (e.g. due to timeout).
        // note that 1) and 2) could be simultaneous (we start app in nearby range)
        // TODO check behaviour in this case: does the "old" session get properly invalidated and new one works?
        // TODO review and test in general: this is more of a quick placeholder implementation.

        // "Device came in max range (which is ble range)" = "meeting started"
        let validatedBlePeer = validDeviceService.device
            .map { $0.id } // discard distance
            // TODO review. For now we process only the first discovered valid device (should be fine?)
            // note also that if we didn't do this, i.e. sent an event on each validation it would be problematic
            // when we implement periodic validation. We're interested here specifically in "came in range",
            // not "determined that the device is valid".
            .removeDuplicates()
            .handleEvents(receiveOutput: { log.d("Discovered valid device, will send nearby discovery token: \($0)", .nearby) })
            .map { _ in () }

        let appCameToFg = appEvents.events
            .filter { $0 == .toFg }
            .map { _ in () }

        sendNearbyTokenCancellable = validatedBlePeer.combineLatest(appCameToFg)
            .sink { _, _ in
                tokenSender.startSending()
            }

        receivedNearbyTokenCancellable = nearbyPairing.token.sink { serializedToken in
            log.i("Received nearby token from peer, starting session", .nearby)
            switch validate(token: serializedToken, sessionStore: sessionStore, tokenProcessor: tokenProcessor) {
            case .valid(let token):
                log.i("Nearby token validation succeeded. Starting nearby session", .nearby)
                nearby.setPeer(token: token)
            case .invalid:
                log.e("Nearby token validation failed. Can't start nearby session", .nearby)
                uiNotifier.show(.error("Nearby peer couldn't be validated. Can't start nearby session"))
            }
        }
    }
}

// TODO consistent retrieval of session data! to sign (get private key), we access keychain directly,
// to validate (retrieve peer's public keys) we access session service. Ideally one single service to
// retrieve session data, or maybe even perform sign/validation with current session data?
// (keep in mind multiple session suspport in the future)
private func validate(token: SerializedSignedNearbyToken, sessionStore: SessionStore,
                      tokenProcessor: NearbyTokenProcessor) -> NearbyTokenValidationResult {
    let res: Result<Peer?, ServicesError> = sessionStore.getSession().map { $0?.peer }
    switch res {
    case .success(let peer):
        if let peer = peer {
            return tokenProcessor.validate(token: token, publicKey: peer.publicKey)
        } else {
            // If we get peer's token to be validated it means we should be in an active session
            // Currently can happen, though, as we don't stop the token observable when
            // the session is deleted --> TODO fix
            log.e("Invalid state: No peers stored (see comment). Can't validate nearby token", .nearby, .session)
            return .invalid
        }
    case .failure(let e):
        log.e("Critical: Couldn't session/peer: \(e). Can't validate nearby token", .nearby)
        return .invalid
    }
}
