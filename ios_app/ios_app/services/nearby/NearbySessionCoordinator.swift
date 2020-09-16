import Foundation
import Combine

protocol NearbySessionCoordinator {}

class NearbySessionCoordinatorImpl: NearbySessionCoordinator {
    private let bleIdService: BleIdService

    private var sendNearbyTokenCancellable: Cancellable?
    private var receivedNearbyTokenCancellable: Cancellable?

    init(bleIdService: BleIdService, nearby: Nearby, nearbyPairing: NearbyPairing,
         keychain: KeyChain, uiNotifier: UINotifier, sessionStore: SessionStore,
         tokenProcessor: NearbyTokenProcessor, validDeviceService: DetectedBleDeviceFilterService,
         appEvents: AppEvents) {
        self.bleIdService = bleIdService

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
                sendNearbyTokenToPeer(nearby: nearby, nearbyPairing: nearbyPairing, keychain: keychain,
                                      uiNotifier: uiNotifier, tokenProcessor: tokenProcessor)
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

// TODO retry(with timer?, additionally to bt write error retry)
// "comes in range" may not work at the distance or be intermittent, so we'll likely get errors
private func sendNearbyTokenToPeer(nearby: Nearby, nearbyPairing: NearbyPairing, keychain: KeyChain,
                                   uiNotifier: UINotifier, tokenProcessor: NearbyTokenProcessor) {
    guard let token = nearby.createOrUseSession() else {
        log.e("Critical: nearby token returned nil. Can't send token to peer.", .nearby)
        return
    }

    // TODO consider making prefs/keychain reactive and fetching reactively. Not sure if benefitial here.
    let mySessionDataRes: Result<Session?, ServicesError> =
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
        log.e("Critical: Couldn't retrieve peers from keychain: \(e). Can't validate nearby token", .nearby)
        return .invalid
    }
}
