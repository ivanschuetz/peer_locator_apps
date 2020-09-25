import Foundation

struct BackendSession {
    let id: SessionId
    let keys: [PublicKey]
}

struct PublicKey: Codable, Equatable {
    let value: String // P521 PEM representation
}

extension PublicKey {
    // Peer here is generic, it can refer to my peer or me as a peer
    func toPeerId(crypto: Crypto) -> PeerId {
        PeerId(value: crypto.sha256(str: value))
    }
}

struct PrivateKey: Codable, Equatable {
    let value: String // P521 PEM representation
}

// Public key hash
struct PeerId: Codable, Equatable {
    let value: String
}

struct Peer: Codable, Equatable {
    let publicKey: PublicKey
}

struct SessionId: Codable, Equatable {
    let value: String
}

// Note: client generated
extension SessionId {
    func createLink() -> SessionLink {
        // Unwrap: we know that the string is a valid url
        // Unwrap: we know that the url is a valid session id, so initializer can't fail
        SessionLink(url: URL(string: "peerfinder://\(value)")!)!
    }
}

struct KeyPair {
    let privateKey: PrivateKey
    let publicKey: PublicKey
}

struct Session: Codable, Equatable {
    let id: SessionId
    let privateKey: PrivateKey
    // TODO (low prio): review: the own public key seems not necessary to store at the moment
    // it may help for debugging? Maybe remove in the future.
    let publicKey: PublicKey
    let peerId: PeerId
    let createdByMe: Bool
    let peer: Peer?
    let isReady: Bool

    func withPeer(_ peer: Peer) -> Session {
        Session(
            id: id,
            privateKey: privateKey,
            publicKey: publicKey,
            peerId: peerId,
            createdByMe: createdByMe,
            peer: peer,
            isReady: isReady
        )
    }

    func withIsReady(_ isReady: Bool) -> Session {
        Session(
            id: id,
            privateKey: privateKey,
            publicKey: publicKey,
            peerId: peerId,
            createdByMe: createdByMe,
            peer: peer,
            isReady: isReady
        )
    }

    func hasPeer() -> Bool {
        peer != nil
    }
}

struct SessionLink {
    let url: URL

    init?(url: URL) {
        // TODO more validation?
        if url.host == nil {
            return nil
        }
        self.url = url
    }

    var sessionId: SessionId {
        // Unwrap: we verified in the initializer that host is not nil
        SessionId(value: url.host!)
    }
}

struct SessionPayloadToSign: Codable {
    // For now a red herring. Normally we should encrypt, with a nonce.
    let id: String
}

enum DetectedPeerSource {
    case ble, nearby
}

struct Location: Equatable {
    let x: Float
    let y: Float
}

struct DetectedPeer: Equatable, Hashable {
    let name: String
    // TODO think about optional distance (and other field). if dist isn't set, should the point disappear or show
    // the last loc with a "stale" status? requires to clear: can dist disappear only when out of range?
    // Note that this applies only to Nearby. BLE dist (i.e. rssi) is maybe always set, but check this too.
    let dist: Float?
    let loc: Location?
    let dir: Direction?
    let src: DetectedPeerSource

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

struct Direction: Equatable {
    let x: Float
    let y: Float
}

extension Direction {
    func toAngle() -> Double {
        // "normal" formula to get angle from x, y (only for positive quadrant): atan(dir.y / dir.x)
        // additions:
        // atan needs adjustment for negative quadrants (x or y < 0)
        let res = Double(atan(y / x))
        if x < 0 {
            return res + Double.pi
        } else if y < 0 {
            return res + (Double.pi * 2)
        } else {
            return res
        }
    }
}
