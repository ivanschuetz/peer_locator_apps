import Foundation
import NearbyInteraction
import MultipeerConnectivity
import Combine

struct NearbyToken: Equatable {
    let data: Data
}

struct SignedNearbyToken: Codable, Equatable {
    let data: Data
    let sig: Data

    init(token: NearbyToken, sig: Data) {
        self.data = token.data
        self.sig = sig
    }
}

struct SerializedSignedNearbyToken {
    let data: Data
}

struct NearbyObj {
    let name: String
    let dist: Float?
    let dir: simd_float3?

    var loc: Location? {
        guard
            let dist = dist,
            let dir = dir
        else { return nil }

        let loc = Location(x: dir.x * dist, y: dir.y * dist)
        log.d("Location: \(loc) calculated from dist: \(dist), dir: \(dir)", .nearby)
        return loc
    }
}

extension NearbyObj: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

// NOTE: assumes only 1 peer: if any (i.e. the only peer) is removed, session state is removed
enum SessionState {
    // TODO do we need to trigger didRemove (or a new state) for didInvalidateWith / sessionSuspensionEnded / sessionWasSuspended?
    case notInit, started, active, removed
}

protocol Nearby {
    var discovered: AnyPublisher<NearbyObj, Never> { get }
    var sessionState: AnyPublisher<SessionState, Never> { get }

    func createOrUseSession() -> NearbyToken?
    func setPeer(token: NearbyToken)
}

func isNearbySupported() -> Bool {
    NISession.isSupported
}

private enum NearbySessionState {
    case active(session: NISession, myToken: NearbyToken, peerToken: NearbyToken?)
    case invalidated
    case inactive
}

private enum NearbyTokenState {
    case active(NearbyToken)
    case notInit
    case invalidated
}

class NearbyImpl: NSObject, Nearby, ObservableObject {

    private var session: NearbySessionState = .inactive

    let discoveredSubject: PassthroughSubject<NearbyObj, Never> = PassthroughSubject()
    lazy var discovered: AnyPublisher<NearbyObj, Never> = discoveredSubject.eraseToAnyPublisher()

    let sessionStateSubject: CurrentValueSubject<SessionState, Never> = CurrentValueSubject(.notInit)
    lazy var sessionState: AnyPublisher<SessionState, Never> = sessionStateSubject.eraseToAnyPublisher()

    /**
     * Creates a new session if there's none yet or it was invalidated, otherwise uses existing one,
     * and returns our discovery token.
     */
    func createOrUseSession() -> NearbyToken? {
        log.v("Called createOrUseSession, state: \(session)", .nearby)

        switch session {
        case .active(_, let myToken, _):
            log.d("There's already an active session, returning dicovery token.", .nearby)
            return myToken
        case .invalidated, .inactive:
            log.d("The session is invalidated or inactive. Creating a new session.", .nearby)
            if let sessionWithToken = createSessionWithToken() {
                self.session = .active(session: sessionWithToken.0, myToken: sessionWithToken.1, peerToken: nil)
                return sessionWithToken.1
            } else {
                return nil
            }
        }
    }

    /**
     * Called when we get the discovery token from peer (peer writes it via ble when we're in range)
     * We expect a nearby session to be initialized here and not have a peer yet.
     */
    func setPeer(token peerToken: NearbyToken) {
        switch session {
        case .active(let niSession, let myToken, let currentPeerToken):
            if currentPeerToken != nil {
                log.w("Invalid state? setting peer while there's already a peer set: \(sessionState).",
                      .nearby)
            }
            if peerToken != currentPeerToken {
                log.d("Running nearby session with new peer token", .nearby)
                session = .active(session: niSession, myToken: myToken, peerToken: peerToken)
                runSession(session: niSession, peerToken: peerToken)
            } else {
                log.w("Got an already active peer token. Doing nothing.", .nearby)
            }
        case .invalidated:
            // This may happen when device is sent to background during a session, ble writes nearby token
            // just after the background timeout invalidates the nearby session.
            // With the current implementation this seems unlikely though. TODO revisit.
            log.w("Trying to set peer on invalidated session. Doing nothing.", .nearby)
        case .inactive:
            log.e("Invalid state: trying to set peer while session is not active", .nearby)
        }
    }

    private func createSessionWithToken() -> (NISession, NearbyToken)? {
        let session = NISession()
        session.delegate = self
        if let token = session.discoveryToken {
            return (session, token.toNearbyToken())
        } else {
            if isNearbySupported() {
                // TODO can this happen? Docs currently don't say when it's nil:
                // https://developer.apple.com/documentation/nearbyinteraction/nisession/3564775-discoverytoken
                log.e("Unexpected: device is supported but nearby session returned no discovery token", .nearby)
                // If we can't create our token there doesn't seem to be a point in having a session, so nil.
                return nil
            } else {
                fatalError("Illegal state: if device doesn't support Nearby, NearbyImpl shouldn't be instantiated")
            }
        }
    }

    private func runSession(session: NISession, peerToken: NearbyToken) {
        session.run(peerToken)
        sessionStateSubject.send(.started) // TODO does nearby have a callback for this?
    }

    /**
     * Runs the session if the peer token is set.
     */
    private func tryRunSession() -> Bool {
        switch session {
        case .active(let session, _, let peerToken):
            if let peerToken = peerToken {
                runSession(session: session, peerToken: peerToken)
                return true
            } else {
                log.e("Invalid state: trying to run session without cached token", .nearby)
                return false
            }
        case .invalidated:
            log.e("Probably invalid state: trying to run invalidated session", .nearby)
            return false
        case .inactive:
            log.e("Probably invalid state: trying to run inactive session", .nearby)
            return false
        }
    }
}

private extension NISession {
    func run(_ token: NearbyToken) {
        let config = NINearbyPeerConfiguration(peerToken: token.toNIDiscoveryToken())
        log.d("Will run nearby session", .nearby)
        run(config)
    }
}

private extension NearbyToken {
    func toNIDiscoveryToken() -> NIDiscoveryToken {
        do {
            guard let deserializedToken = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(self.data) else {
                fatalError("Unexpected: deserialized Nearby token is nil")
            }
            guard let nearbyToken = deserializedToken as? NIDiscoveryToken else {
                fatalError("Unexpected: couldn't cast deserialized token to Nearby token." +
                    "Deserialized token: \(deserializedToken), token: \(self)")
            }
            log.v("Deserialized peer Nearby token: \(String(describing: nearbyToken))", .nearby)

            return nearbyToken

        } catch (let e) {
            fatalError("Unexpected: couldn't deserialize Nearby token. Error: \(e)")
        }
    }
}

private extension NIDiscoveryToken {
    func toNearbyToken() -> NearbyToken {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self as Any, requiringSecureCoding: true)
            log.i("Sending Nearby token: \(String(describing: self)) to peer", .nearby, .peer)
            return NearbyToken(data: data)
        } catch (let e) {
            fatalError("Unexpected: couldn't serialize discovery token. Can't use Nearby. Error: \(e)")
        }
    }
}

extension NearbyImpl: NISessionDelegate {

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        log.v("Session did update, objects: \(nearbyObjects)", .nearby)

        guard let obj = nearbyObjects.first else { return }

        let discovered = NearbyObj(name: obj.discoveryToken.description, dist: obj.distance.map { $0 * 100 } /*cm*/,
                                   dir: obj.direction)
        sessionStateSubject.send(.active)
        discoveredSubject.send(discovered)
    }

    // Call when session times out or peer ended it
    // (this should include being suspended - i.e. session is still valid, when being sent to bg) TODO confirm
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // TODO refresh token on timeout or when app is reopened. See https://developer.apple.com/documentation/nearbyinteraction/ninearbyobject/removalreason/timeout
//        > The framework times out a session if the peer user closes the app, or if too much time passes in a suspended state (see sessionWasSuspended(_:)). NI may also time out a session to save device resources.
//        > An app must watch for timed-out peers. If the app wishes to continue interaction with a timed-out peer device, the app must begin a new session.
        // TODO investigate behavior: nearby ~10m but ble/multipeer ~100m, with which we exchange token
        // -> wouldn't we get timeout while the user is out of range??
        // but tutorial tells us to use multipeer and it seems we can't measure distance with that, so this can't be true
        // exchange: write or read?


        // TODO clear up:
        // Session not invalidated here, as this seems to be called too when it (it peer's) is only suspended?
        // is peerEnded maybe suspended and timeout invalidated?
        // if timeout is invalidated, set session to .invalidated there too.

        log.d("Objects removed from session: \(nearbyObjects)", .nearby)
        switch reason {
        case .peerEnded: log.d("Reason: peer ended session", .nearby)
        case .timeout: log.d("Reason: session time out (devices may be too far appart)", .nearby)
        @unknown default: log.d("Reason: new (not handled): \(reason)", .nearby) }

        sessionStateSubject.send(.removed)
    }

    // Called when app is sent to bg
    // If back to fg before timeout, sessionSuspensionEnded is called, where we have to re-run the session with the cached discovery token
    // If not, didInvalidate is called. Here we clear the cached token, as the session isn't valid anymore.
    // On the peer's side, didRemove is called, where we also clear the cached token, for the same reason.
    func sessionWasSuspended(_ session: NISession) {
        log.d("sessionWasSuspended", .nearby)

        // It seems we have nothing to do here.

        // See docs https://developer.apple.com/documentation/nearbyinteraction/nisessiondelegate/3601173-sessionwassuspended
        // > When NI invokes this callback, the session suspends and doesn’t receive session(_:didUpdate:) callbacks. NI suspends a session when the user backgrounds the app. If the user reactivates the app before NI times out the session, NI calls sessionSuspensionEnded(_:). A suspended session won’t resume on its own. To resume the session, call run(_:) again, passing in your session’s configuration.

        // > If the app stays backgrounded for too long during a suspension, NI invalidates the session (see session(_:didInvalidateWith:)) and the peer user’s session invokes session(_:didRemove:reason:) with reason NINearbyObject.RemovalReason.timeout.

        // > Additionally, the system may suspend a session for internal reasons.
    }

    // Called when app comes back to fg before session timeout. The session/token is still valid, we just have to re-run.
    func sessionSuspensionEnded(_ session: NISession) {
        log.d("sessionSuspensionEnded", .nearby)
        _ = tryRunSession()
    }

    // Called when session times out (app stays in bg too long, errors). Clear peer token.
    func session(_ session: NISession, didInvalidateWith error: Error) {
        log.e("Session was invalidated. Error: \(error)", .nearby)
        // called on error conditions or resource constraints

        self.session = .invalidated

        // TODO test: when exactly is this called? if it's while the app is in bg
        // it seems pointless to restart the session here.
        // for now assuming this is the case and restarting session on fg event.

        // See docs https://developer.apple.com/documentation/nearbyinteraction/nisessiondelegate/3571263-session
        // > The delegate of an invalidated session receives no further callbacks, and the app can’t restart the session. To resume peer interaction, remove references to the invalidated session and begin a new session.
    }
}

// Note used also in production, by devices that don't support Nearby.
class NearbyNoop: Nearby {
    var sessionState = Just(SessionState.notInit).eraseToAnyPublisher()
    var discovered: AnyPublisher<NearbyObj, Never> = Empty()
        .eraseToAnyPublisher()
    func createOrUseSession() -> NearbyToken? { nil }
    func setPeer(token: NearbyToken) {}
}
