import Foundation
import Combine

/**
 * Sends the nearby token to peer
 * Since we aren't sure that the peer is in (Nearby) range or there may be some intermittency at the edges
 * (which is where we start the Nearby pairing)
 * each peer just keeps sending the token until it succeeds (a Nearby session is etablished)
 * Note that if for whatever reason a peer receives a token again after the nearby session already started with it,
 * it's not an issue. Receiving repeated Nearby peer tokens is just ignored.
 */
protocol NearbyTokenSender {
    func startSending()
}

class NearbyTokenSenderImpl: NearbyTokenSender {
    private let nearbyPairing: NearbyPairing
    private let tokenProcessor: NearbyTokenProcessor
    private let localSessionManager: LocalSessionManager
    private let uiNotifier: UINotifier
    private let nearby: Nearby

    private var sessionStateCancellable: AnyCancellable?
    private var timer: Timer?

    private var keepSendingAfterSessionActiveTimer: Timer?
    
    init(nearbyPairing: NearbyPairing, tokenProcessor: NearbyTokenProcessor, localSessionManager: LocalSessionManager,
         uiNotifier: UINotifier, nearby: Nearby) {
        self.nearbyPairing = nearbyPairing
        self.tokenProcessor = tokenProcessor
        self.localSessionManager = localSessionManager
        self.uiNotifier = uiNotifier
        self.nearby = nearby

        sessionStateCancellable = nearby.sessionState
            .removeDuplicates()
            .filter { $0 == .active }
            .sink { [weak self] sessionState in
                self?.startStopSendingAfterSessionActiveTimer()
        }
    }

    func startSending() {
        cancelTimer()
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(onTimerTick),
                                     userInfo: nil, repeats: true)
        timer?.tolerance = 1
        //        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(onTimerTick),
        //                                     userInfo: nil, repeats: true)
        sendNearbyTokenToPeer()
    }

    private func startStopSendingAfterSessionActiveTimer() {
        // Nearby session becoming active apparently is one sided: our peer session
        // is not necessarily active yet. So we keep sending the token a while.
        // TODO review this, test on devices.
        log.d("Nearby session active. Start timer to stop sending token.", .nearby)
        cancelKeepSendingAfterSessionActiveTimer()
        keepSendingAfterSessionActiveTimer = Timer.scheduledTimer(
            timeInterval: 30, target: self, selector: #selector(onkeepSendingAfterSessionActiveTimer),
            userInfo: nil, repeats: false)
        keepSendingAfterSessionActiveTimer?.tolerance = 1
    }

    @objc private func onkeepSendingAfterSessionActiveTimer() {
        cancelKeepSendingAfterSessionActiveTimer()
        log.d("Keep sending nearby token timer fired. Stop sending token.", .nearby)
        stopSending()
    }

    private func cancelKeepSendingAfterSessionActiveTimer() {
        keepSendingAfterSessionActiveTimer?.invalidate()
        keepSendingAfterSessionActiveTimer = nil
    }

    private func stopSending() {
        log.d("Stopping sending nearby token", .nearby)
        cancelTimer()
    }

    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func onTimerTick() {
        log.v("Timer tick: sending nearby token to peer...", .nearby)
        sendNearbyTokenToPeer()
    }

    // TODO aside of this "retry" implement also low level ble retry
    private func sendNearbyTokenToPeer() {
        nearby.createOrUseSession { [weak self] token in
            if let token = token {
                self?.sendToken(token: token)
            } else {
                log.e("Critical: nearby token returned nil. Can't send token to peer.", .nearby)
                return
            }
        }
    }

    private func sendToken(token: NearbyToken) {
        // This is a bit ineficcient: maybe we should observe the current session instead
        // but then it's difficult to see error if there's no session initialized when the timer fires?
        switch localSessionManager.getSession() {
        case .success(let mySessionData):
            if let mySessionData = mySessionData {
                log.i("Sending nearby discovery token to peer: \(token)", .nearby)
                nearbyPairing.sendDiscoveryToken(
                    token: tokenProcessor.prepareToSend(token: token, privateKey: mySessionData.privateKey)
                )
            } else {
                // We're observing a validated peer, and validating is not possible without
                // having our own private key stored, so it _should_ be invalid state. but:
                // This currently can happen when triggered by (nearby) session stopped observable
                // after the (peer) session were deleted --> TODO fix
                // also, consider observing the current session too (and ensuring that the keychain data
                // is in sync, so if current session is nil, keychain data is also reliably deleted
                // NOTE: currently valid on the simulator, as peer validation is always true
                log.e("Invalid state: no session data (see comment for details)", .nearby, .session)
            }

        case .failure(let e):
            log.e("Failure fetching session data. Can't start nearby session. \(e)", .nearby)
            // TODO we really should prevent this (see comments above): it would be terrible ux
            // also, allow the user to report errors from the notification
            uiNotifier.show(.error("Failure initiating high-accuracy tracking session."))
        }
    }
}
