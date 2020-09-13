import Foundation
import Combine

protocol NearbySessionCoordinator {}

class NearbySessionCoordinatorImpl: NearbySessionCoordinator {
    private let bleManager: BleManager
    private let bleIdService: BleIdService

    private var sendNearbyTokenCancellable: Cancellable?
    private var receivedNearbyTokenCancellable: Cancellable?

    init(bleManager: BleManager, bleIdService: BleIdService, nearby: Nearby, nearbyPairing: NearbyPairing,
         keychain: KeyChain, uiNotifier: UINotifier, sessionService: SessionService,
         tokenProcessor: NearbyTokenProcessor) {
        self.bleManager = bleManager
        self.bleIdService = bleIdService

        // Idea is to send the nearby token (i.e. initiate the session) when
        // 1) the devices come in ble range (to be tested whether this doesn't trigger nearby timeout/invalidation)
        // 2) the nearby connection was invalidated (e.g. due to timeout).
        // note that 1) and 2) could be simultaneous (we start app in nearby range)
        // TODO check behaviour in this case: does the "old" session get properly invalidated and new one works?
        // TODO review and test in general: this is more of a quick placeholder implementation.

        // "Device came in max range (which is ble range)" = "meeting started"
        let validatedBlePeer = bleManager.discovered
            .map { $0.id } // discard distance
            // TODO review. For now we process only the first discovered id (should be fine?)
            .removeDuplicates()
            .handleEvents(receiveOutput: { log.d("Discovered device, will validate: \($0)", .nearby) })
            // NOTE: this validation isn't related with nearby token validation. This is just to
            // identify the event "peer detected (i.e. is in max possible range)"
            // which of course has to be a validated peer (correct general signature)
            // TODO this is obviously very inefficient, as we get a new id per distance measurement!
            // currently we validate only once. Note: Added removeDuplicates() above. If that's ok this todo can be removed.
            .map { bleIdService.validate(bleId: $0) }
//            .handleEvents(receiveOutput: { log.d("Validated device: \($0)", .nearby) })
            .removeDuplicates()
            .filter { $0 }
            .map { _ in () }
            
        let sessionStopped = nearby.sessionState
            .handleEvents(receiveOutput: { log.d("Session state: \($0)", .nearby) })
            .removeDuplicates()
            .filter { $0 == .removed }
            .map { _ in () }

        sendNearbyTokenCancellable = validatedBlePeer.merge(with: sessionStopped)
            .sink { _ in
                sendNearbyTokenToPeer(nearby: nearby, nearbyPairing: nearbyPairing, keychain: keychain,
                                      uiNotifier: uiNotifier, tokenProcessor: tokenProcessor)
            }

        receivedNearbyTokenCancellable = nearbyPairing.token.sink { serializedToken in
            log.i("Received nearby token from peer, starting session", .nearby)
            switch validate(token: serializedToken, sessionService: sessionService, tokenProcessor: tokenProcessor) {
            case .valid(let token):
                log.i("Nearby token validation succeeded. Starting nearby session", .nearby)
                nearby.start(peerToken: token)
            case .invalid:
                log.e("Nearby token validation failed. Can't start nearby session", .nearby)
                uiNotifier.show(.error("Nearby peer couldn't be validated. Can't start nearby session"))
            }
        }
    }
}

private func sendNearbyTokenToPeer(nearby: Nearby, nearbyPairing: NearbyPairing, keychain: KeyChain,
                                   uiNotifier: UINotifier, tokenProcessor: NearbyTokenProcessor) {
    if let token = nearby.token() {

        // TODO consider making prefs/keychain reactive and fetching reactively. Not sure if benefitial here.
        let mySessionDataRes: Result<MySessionData?, ServicesError> =
            keychain.getDecodable(key: .mySessionData)
        switch mySessionDataRes {
        case .success(let mySessionData):
            if let mySessionData = mySessionData {
                log.i("Sending nearby discovery token to peer: \(token)", .nearby)
                nearbyPairing.sendDiscoveryToken(
                    token: tokenProcessor.prepareToSend(token: token, privateKey: mySessionData.privateKey)
                )
            } else {
                // We're observing a validated peer, and validating is not possible without
                // having our own private key stored, so it _should_ be invalid. but:
                // This currently can happen when triggered by (nearby) session stopped observable
                // after the (peer) session were deleted --> TODO fix
                // also, consider observing the current session too (and ensuring that the keychain data
                // is in sync, so if current session is nil, keychain data is also reliably deleted
                log.e("Invalid state: no session data (see comment for details)", .nearby, .session)
            }

        case .failure(let e):
            log.e("Failure fetching session data. Can't start nearby session. \(e)", .nearby)
            // TODO we really should prevent this (see comments above): it would be terrible ux
            // also, allow the user to report errors from the notification
            uiNotifier.show(.error("Couldn't start nearby session"))
        }
    } else {
        log.e("Critical: nearby token returned nil. Can't send token to peer.", .nearby)
    }
}

// TODO consistent retrieval of session data! to sign (get private key), we access keychain directly,
// to validate (retrieve peer's public keys) we access session service. Ideally one single service to
// retrieve session data, or maybe even perform sign/validation with current session data?
// (keep in mind multiple session suspport in the future)
private func validate(token: SerializedSignedNearbyToken, sessionService: SessionService,
                      tokenProcessor: NearbyTokenProcessor) -> NearbyTokenValidationResult {
    let res: Result<Participants?, ServicesError> = sessionService.currentSessionParticipants()
    switch res {
    case .success(let participants):
        if let participants = participants {
            // TODO we should allow to retrieve only the peer instead of "participants" (which includes the own public key)
            for publicKey in participants.participants {
                let res = tokenProcessor.validate(token: token, publicKey: publicKey)
                if case .valid = res {
                    return res
                }
            }
            return .invalid
        } else {
            // If we get peer's token to be validated it means we should be in an active session
            // Currently can happen, though, as we don't stop the token observable when
            // the session is deleted --> TODO fix
            log.e("Invalid state: No participants stored (see comment). Can't validate nearby token", .nearby, .session)
            return .invalid
        }
    case .failure(let e):
        log.e("Critical: Couldn't retrieve participants from keychain: \(e). Can't validate nearby token", .nearby)
        return .invalid
    }
}
