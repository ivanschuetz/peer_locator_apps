import Foundation
import MultipeerConnectivity

protocol TokenServiceDelegate {
    func sessionReady()
    func receivedToken(token: Data)
}

// TODO do we really want multipeer framework?
// we need Android <-> iOS for level 1 detection: multipeer doesn't work with Android
// so since we need BLE for that anyway, we could use BLE too to interchange nearby tokens?
// level 1 requires authentication, so we'd have an already authenticated channel,
// which we don't have here. We'd have to implement authentication here too -> 2x code.
// conclusion: move this to BLE

class TokenService: NSObject {
    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)

    private let serviceAdvertiser: MCNearbyServiceAdvertiser
    private let serviceBrowser: MCNearbyServiceBrowser

    private let serviceType = "schuetzmatch"
    private let serviceIdentity = "com.schuetz.ios-app./device_ni"

    var delegate: TokenServiceDelegate?

    lazy var session : MCSession = {
        let session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        log.v("Created MC session", .peer)
        return session
    }()

    override init() {
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId,
                                                           discoveryInfo: ["identity" : serviceIdentity],
                                                           serviceType: serviceType)

        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        super.init()
        serviceAdvertiser.delegate = self
        serviceBrowser.delegate = self
    }

    func start() {
        log.d("Starting MC advertiser and browser", .peer)
        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser.startBrowsingForPeers()
        _ = session // trigger lazy init
    }

    func send(token: Data) {
        log.i("Sending token: \(token) to \(session.connectedPeers.count) peer(s)", .peer)
        if session.connectedPeers.count > 0 {
            do {
                try session.send(token, toPeers: session.connectedPeers, with: .reliable)
            }
            catch let error {
                log.e("Error sending token: \(error)", .peer)
            }
        }
    }

    deinit {
        serviceAdvertiser.stopAdvertisingPeer()
    }
}

extension TokenService : MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        log.e("didNotStartAdvertisingPeer: \(error)", .peer)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        log.i("didReceiveInvitationFromPeer \(peerID)", .peer)
        invitationHandler(true, session)
    }
}

extension TokenService : MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        log.w("didNotStartBrowsingForPeers: \(error)", .peer)
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        log.i("Found peer: \(peerID), inviting...", .peer)
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        log.d("Lost peer: \(peerID)", .peer)
    }
}

extension TokenService : MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        log.d("Peer \(peerID) didChangeState: \(state.rawValue)", .peer)
        switch state {
        case .connected:
            log.i("Session connected!", .peer)
            delegate?.sessionReady()
        case .connecting:
            log.d("Session connecting...", .peer)
        case .notConnected:
            log.d("Session not connected", .peer)
        @unknown default:
            log.w("New MC session state: \(state)", .peer)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        log.i("Peer received token: \(data)", .peer)
        delegate?.receivedToken(token: data)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        log.d("didReceiveStream", .peer)
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        log.d("didStartReceivingResourceWithName", .peer)
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        log.d("didFinishReceivingResourceWithName", .peer)
    }
}
