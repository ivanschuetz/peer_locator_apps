import Foundation
import MultipeerConnectivity
import Combine

protocol TokenServiceDelegate {
    func receivedToken(token: SerializedSignedNearbyToken)
}

class MultipeerTokenServiceImpl: NSObject, NearbyTokenReceiver {
    private let tokenSubject = CurrentValueSubject<SerializedSignedNearbyToken?, Never>(nil)
    lazy var token = tokenSubject.compactMap{ $0 }.eraseToAnyPublisher()

    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)

    private let serviceAdvertiser: MCNearbyServiceAdvertiser
    private let serviceBrowser: MCNearbyServiceBrowser

    private let serviceType = "schuetzmatch"
    private let serviceIdentity = "com.schuetz.ios-app./device_ni"

    var delegate: TokenServiceDelegate?

    private let tokenToSend = PassthroughSubject<SerializedSignedNearbyToken, Never>()
    private let connectionReady = PassthroughSubject<(), Never>()

    private var sendTokenCancellable: Cancellable?

    lazy var session: MCSession = {
        let session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        log.v("Created MC session", .peer)
        return session
    }()

    override init() {
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId,
                                                           discoveryInfo: ["identity": serviceIdentity],
                                                           serviceType: serviceType)

        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        super.init()
        serviceAdvertiser.delegate = self
        serviceBrowser.delegate = self

        sendTokenCancellable = connectionReady.combineLatest(tokenToSend)
            .map{ _, token in token }
            .sink { [weak self] token in
                log.d("Connection and token to send ready, sending token", .peer)
                self?.actuallySendToken(token: token)
            }

        start()
    }

    func start() {
        log.d("Starting MC advertiser and browser", .peer)
        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser.startBrowsingForPeers()
        _ = session // trigger lazy init
    }

    deinit {
        serviceAdvertiser.stopAdvertisingPeer()
    }

    private func actuallySendToken(token: SerializedSignedNearbyToken) {
        log.i("Sending token: \(token) to \(session.connectedPeers.count) peer(s)", .peer)
        if session.connectedPeers.count > 0 {
            do {
                try session.send(token.data, toPeers: session.connectedPeers, with: .reliable)
            }
            catch let error {
                log.e("Error sending token: \(error)", .peer)
            }
        }
    }
}

extension MultipeerTokenServiceImpl: NearbyTokenSender {
    func sendDiscoveryToken(token: SerializedSignedNearbyToken) {
        tokenToSend.send(token)
    }
}

extension MultipeerTokenServiceImpl: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        log.e("didNotStartAdvertisingPeer: \(error)", .peer)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        log.i("didReceiveInvitationFromPeer \(peerID)", .peer)
        invitationHandler(true, session)
    }
}

extension MultipeerTokenServiceImpl: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        log.w("didNotStartBrowsingForPeers: \(error)", .peer)
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        log.i("Found peer: \(peerID), inviting...", .peer)
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        log.d("Lost peer: \(peerID)", .peer)
    }
}

extension MultipeerTokenServiceImpl: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        log.d("Peer \(peerID) didChangeState: \(state.rawValue)", .peer)
        switch state {
        case .connected:
            log.i("Session connected!", .peer)
            connectionReady.send(())
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
        tokenSubject.send(SerializedSignedNearbyToken(data: data))
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
