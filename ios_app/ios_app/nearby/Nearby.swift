import Foundation
import NearbyInteraction
import MultipeerConnectivity
import Combine

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

protocol Nearby {
    var discovered: AnyPublisher<NearbyObj, Never> { get }
}

class NearbyImpl: NSObject, Nearby, ObservableObject {

    var session: NISession?

    let discoveredSubject: PassthroughSubject<NearbyObj, Never> = PassthroughSubject()
    lazy var discovered: AnyPublisher<NearbyObj, Never> = discoveredSubject.eraseToAnyPublisher()

    private let tokenService: TokenService

    init(tokenService: TokenService) {
        self.tokenService = tokenService
        super.init()

        start()
    }

    // Starts the token service to exchange tokens and nearby when token available
    private func start() {
        guard NISession.isSupported else {
            log.w("This device doesn't support nearby", .nearby)
            return
        }

        log.i("Starting Nearby", .nearby)

        let session = NISession()
        session.delegate = self
        self.session = session

        tokenService.delegate = self
        tokenService.start()
    }

    // Note: Direct dependency in (MC) token service (not ideal)
    func sendMyTokenToPeer() {
        guard let session = session else {
            fatalError("Session not initialized.")
        }

        let token = session.discoveryToken
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token as Any, requiringSecureCoding: true)
            log.i("Sending Nearby token: \(String(describing: token)) to peer", .nearby, .peer)
            tokenService.send(token: data)
        } catch (let e) {
            fatalError("Unexpected: couldn't serialize discovery token. Can't use Nearby. Error: \(e)")
        }
    }
}

extension NearbyImpl: TokenServiceDelegate {

    func sessionReady() {
        sendMyTokenToPeer()
    }

    func receivedToken(token: Data) {
        guard let session = session else {
            fatalError("Session not initialized.")
        }

        do {
            guard let deserializedToken = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(token) else {
                fatalError("Unexpected: deserialized Nearby token is nil")
            }
            guard let nearbyToken = deserializedToken as? NIDiscoveryToken else {
                fatalError("Unexpected: couldn't cast deserialized token to Nearby token." +
                    "Deserialized token: \(deserializedToken), token: \(token)")
            }
            log.v("Deserialized peer Nearby token: \(String(describing: nearbyToken))", .nearby)

            let config = NINearbyPeerConfiguration(peerToken: nearbyToken)
            log.d("Will run nearby session", .nearby)
            session.run(config)

        } catch (let e) {
            fatalError("Unexpected: couldn't deserialize Nearby token. Error: \(e)")
        }
    }
}

extension NearbyImpl: NISessionDelegate {

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        log.d("Session did update, objects: \(nearbyObjects)", .nearby)

        guard let obj = nearbyObjects.first else { return }

        let discovered = NearbyObj(name: obj.discoveryToken.description, dist: obj.distance.map { $0 * 100 } /*cm*/,
                                   dir: obj.direction)
        self.discoveredSubject.send(discovered)
    }

    // Peer gone
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        log.d("Objects removed from session: \(nearbyObjects)", .nearby)
        switch reason {
        case .peerEnded: log.d("Reason: peer ended session", .nearby)
        case .timeout: log.d("Reason: session time out (devices may be too far appart)", .nearby)
        @unknown default: log.d("Reason: new (not handled): \(reason)", .nearby) }
    }

    func sessionWasSuspended(_ session: NISession) {
        log.d("sessionWasSuspended", .nearby)
        // e.g. when app to bg
    }

    func sessionSuspensionEnded(_ session: NISession) {
        log.d("sessionSuspensionEnded", .nearby)
        // call run on stored session again
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        log.e("Session was invalidated. Error: \(error)", .nearby)
        // called on error conditions or resource constraints
        // TODO (?): re-create session, exchange etc?
    }
}
