import Foundation
import NearbyInteraction
import MultipeerConnectivity
import Combine

struct NearbyToken {
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

    func token() -> NearbyToken?
    func start(peerToken: NearbyToken)
}

class NearbyImpl: NSObject, Nearby, ObservableObject {

    private let session: NISession

    let discoveredSubject: PassthroughSubject<NearbyObj, Never> = PassthroughSubject()
    lazy var discovered: AnyPublisher<NearbyObj, Never> = discoveredSubject.eraseToAnyPublisher()

    let sessionStateSubject: CurrentValueSubject<SessionState, Never> = CurrentValueSubject(.notInit)
    lazy var sessionState: AnyPublisher<SessionState, Never> = sessionStateSubject.eraseToAnyPublisher()

    override init() {
        let session = NISession()
        self.session = session
        super.init()
        session.delegate = self
    }

    // TODO use
    static func isSupported() -> Bool {
        NISession.isSupported
//      log.w("This device doesn't support nearby", .nearby)
    }

    // TODO when does discoveryToken return nil? when session not supported at least?
    func token() -> NearbyToken? {
        session.discoveryToken?.toNearbyToken()
    }

    func start(peerToken: NearbyToken) {
        let config = NINearbyPeerConfiguration(peerToken: peerToken.toNIDiscoveryToken())
        log.d("Will run nearby session", .nearby)
        session.run(config)
        sessionStateSubject.send(.started)
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
        log.d("Session did update, objects: \(nearbyObjects)", .nearby)

        guard let obj = nearbyObjects.first else { return }

        let discovered = NearbyObj(name: obj.discoveryToken.description, dist: obj.distance.map { $0 * 100 } /*cm*/,
                                   dir: obj.direction)
        discoveredSubject.send(discovered)

        sessionStateSubject.send(.active)
    }

    // Peer gone
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // TODO refresh token on timeout or when app is reopened. See https://developer.apple.com/documentation/nearbyinteraction/ninearbyobject/removalreason/timeout
//        > The framework times out a session if the peer user closes the app, or if too much time passes in a suspended state (see sessionWasSuspended(_:)). NI may also time out a session to save device resources.
//        > An app must watch for timed-out peers. If the app wishes to continue interaction with a timed-out peer device, the app must begin a new session.
        // TODO investigate behavior: nearby ~10m but ble/multipeer ~100m, with which we exchange token
        // -> wouldn't we get timeout while the user is out of range??
        // but tutorial tells us to use multipeer and it seems we can't measure distance with that, so this can't be true
        // exchange: write or read?
        //
        log.d("Objects removed from session: \(nearbyObjects)", .nearby)
        switch reason {
        case .peerEnded: log.d("Reason: peer ended session", .nearby)
        case .timeout: log.d("Reason: session time out (devices may be too far appart)", .nearby)
        @unknown default: log.d("Reason: new (not handled): \(reason)", .nearby) }

        sessionStateSubject.send(.removed)
    }

    func sessionWasSuspended(_ session: NISession) {
        log.d("sessionWasSuspended", .nearby)
        // e.g. when app to bg

        // TODO does this need handling?
        // See docs https://developer.apple.com/documentation/nearbyinteraction/nisessiondelegate/3601173-sessionwassuspended
        // > When NI invokes this callback, the session suspends and doesn’t receive session(_:didUpdate:) callbacks. NI suspends a session when the user backgrounds the app. If the user reactivates the app before NI times out the session, NI calls sessionSuspensionEnded(_:). A suspended session won’t resume on its own. To resume the session, call run(_:) again, passing in your session’s configuration.

        // > If the app stays backgrounded for too long during a suspension, NI invalidates the session (see session(_:didInvalidateWith:)) and the peer user’s session invokes session(_:didRemove:reason:) with reason NINearbyObject.RemovalReason.timeout.

        // > Additionally, the system may suspend a session for internal reasons.
    }

    func sessionSuspensionEnded(_ session: NISession) {
        log.d("sessionSuspensionEnded", .nearby)
        // call run on stored session again
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        log.e("Session was invalidated. Error: \(error)", .nearby)
        // called on error conditions or resource constraints
        // TODO (?): re-create session, exchange etc?

        // See docs https://developer.apple.com/documentation/nearbyinteraction/nisessiondelegate/3571263-session
        // > The delegate of an invalidated session receives no further callbacks, and the app can’t restart the session. To resume peer interaction, remove references to the invalidated session and begin a new session.
    }
}
