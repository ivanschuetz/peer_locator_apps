import Foundation
import Combine

protocol NearbySessionCoordinator {}

/**
 * Triggers sending of Nearby token to peer and processes received Nearby token.
 */
class NearbySessionCoordinatorImpl: NearbySessionCoordinator {
    private var sendNearbyTokenCancellable: Cancellable?
    private var receivedNearbyTokenCancellable: Cancellable?

    init(nearby: Nearby, nearbyPairing: NearbyPairing, uiNotifier: UINotifier, localSessionManager: LocalSessionManager,
         tokenProcessor: NearbyTokenProcessor, validatedPeerEvent: ValidatedPeerEvent,
         appEvents: AppEvents, tokenSender: NearbyTokenSender, currentSession: CurrentSessionService) {

        // Idea is to send the nearby token (i.e. initiate the session) when
        // 1) the devices come in ble range (to be tested whether this doesn't trigger nearby timeout/invalidation)
        // 2) the nearby connection was invalidated (e.g. due to timeout).
        // note that 1) and 2) could be simultaneous (we start app in nearby range)
        // TODO check behaviour in this case: does the "old" session get properly invalidated and new one works?
        // TODO review and test in general: this is more of a quick placeholder implementation.

        let appCameToFg = appEvents.events
            .filter { $0 == .toFg }
            .map { _ in () }

        // Start sending discovery token periodically after app came to fg
        // we do this because the session may be invalidated while in bg
        // NearbyTokenSender stops sending when the session is activated.
        // if the session was not invalidated, this should be a Noop (TODO confirm)
        // as we'd be sending the already active discovery token and peer will ignore it.
        sendNearbyTokenCancellable = validatedPeerEvent.event.combineLatest(appCameToFg)
            .handleEvents(receiveOutput: { _, _ in log.v("Received valid peer and app fg event", .nearby) })
            .combineLatest(currentSession.session)
            .handleEvents(receiveOutput: { _, _ in log.v("Received valid peer, app fg and session event", .nearby) })
            .sink { (_, sessionState) in
                if sessionState.isReady() {
                    log.d("Starting periodic sending of nearby token to peer", .nearby)
                    tokenSender.startSending()
                } else {
                    log.d("Not starting periodic sending of nearby token, since there's not a ready session.", .nearby)
                }
            }

        receivedNearbyTokenCancellable = nearbyPairing.token.sink { serializedToken in
            log.i("Received nearby token from peer, starting session", .nearby)
            switch validate(token: serializedToken, localSessionManager: localSessionManager,
                            tokenProcessor: tokenProcessor) {
            case .success(.valid(let token)):
                log.i("Nearby token validation succeeded. Starting nearby session", .nearby)
                nearby.setPeer(token: token)
            case .success(.invalid):
                log.e("Nearby token validation failed. Can't start nearby session", .nearby)
                uiNotifier.show(.error("Can't start high-accuracy tracking: peer invalid"))
            case .failure(let e):
                log.e("Nearby token validation returned an error: \(e). Can't start nearby session", .nearby)
                uiNotifier.show(.error("Unknown error starting high-accuracy tracking"))
            }
        }
    }
}

// TODO consistent retrieval of session data! to sign (get private key), we access keychain directly,
// to validate (retrieve peer's public keys) we access session service. Ideally one single service to
// retrieve session data, or maybe even perform sign/validation with current session data?
// (keep in mind multiple session suspport in the future)
private func validate(token: SerializedSignedNearbyToken, localSessionManager: LocalSessionManager,
                      tokenProcessor: NearbyTokenProcessor) -> Result<NearbyTokenValidationResult, ServicesError> {
    localSessionManager.withSession { session in
        if let peer = session.peer {
            return tokenProcessor.validate(token: token, publicKey: peer.publicKey)
        } else {
            // If we get peer's token to be validated it means we should be in an active session
            // Currently can happen, though, as we don't stop the token observable when
            // the session is deleted --> TODO fix
            log.e("Invalid state: No peer stored (see comment). Can't validate nearby token", .nearby, .session)
            return .success(.invalid)
        }
    }
}
