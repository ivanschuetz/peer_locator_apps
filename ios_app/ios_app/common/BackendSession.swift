import Foundation

struct BackendSession {
    let id: SessionId
    let keys: [PublicKey]
}

struct PublicKey: Codable, Equatable {
    let value: String // P521 PEM representation
}

extension PublicKey {
    func toPeerId(crypto: Crypto) -> PeerId {
        PeerId(value: crypto.sha256(str: value))
    }
}

struct PrivateKey: Codable {
    let value: String // P521 PEM representation
}

// Note: client generated
extension SessionId {
    func createLink() -> SessionLink {
        // Unwrap: we know that the string is a valid url
        // Unwrap: we know that the url is a valid session id, so initializer can't fail
        SessionLink(url: URL(string: "ploc://\(value)")!)!
    }
}

struct KeyPair {
    let private_key: PrivateKey
    let public_key: PublicKey
}

struct Session: Codable {
    let id: SessionId
    let privateKey: PrivateKey
    // TODO (low prio): review: the own public key seems not necessary to store at the moment
    // it may help for debugging? Maybe remove in the future.
    let publicKey: PublicKey
    let peerId: PeerId
    let createdByMe: Bool
    let peer: Peer?

    func withPeer(peer: Peer) -> Session {
        Session(
            id: id,
            privateKey: privateKey,
            publicKey: publicKey,
            peerId: peerId,
            createdByMe: createdByMe,
            peer: peer
        )
    }

    func isReady() -> Bool {
        peer != nil
    }
}

struct Peer: Codable {
    let publicKey: PublicKey
}

// Public key hash
struct PeerId: Codable {
    let value: String
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
