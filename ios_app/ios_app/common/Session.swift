import Foundation

// TODO rename in Meeting (and related)
struct Session {
    let id: SessionId
    let keys: [PublicKey]
}

struct PublicKey: Encodable, Decodable {
    let value: String // P521 PEM representation
}

extension PublicKey {
    func toParticipantId(crypto: Crypto) -> ParticipantId {
        ParticipantId(value: crypto.sha256(str: value))
    }
}

struct PrivateKey: Encodable, Decodable {
    let value: String // P521 PEM representation
}


extension SessionId {
    func createLink() -> SessionLink {
        SessionLink(value: URL(string: "ploc://\(value)")!)
    }
}

struct KeyPair {
    let private_key: PrivateKey
    let public_key: PublicKey
}

// TODO rename (My)ParticipantData or similar, maybe?
struct MySessionData: Encodable, Decodable {
    let sessionId: SessionId
    let privateKey: PrivateKey
    // TODO (low prio): review: the own public key seems not necessary to store at the moment
    // it may help for debugging? Maybe remove in the future.
    let publicKey: PublicKey
    let participantId: ParticipantId
    let createdByMe: Bool
}

struct ParticipantId: Encodable, Decodable {
    let value: String
}

struct Participants: Encodable, Decodable {
    let participants: [PublicKey]
}

struct SessionLink {
    let value: URL
    // TODO validate URL on initialization
}

extension SessionLink {
    func extractSessionId() -> Result<SessionId, ServicesError> {
        if let id = value.host {
            return .success(SessionId(value: id))
        } else {
            return .failure(.general("Invalid session link: \(self)"))
        }
    }
}

struct SessionPayloadToSign: Encodable, Decodable {
    // For now a red herring. Normally we should encrypt, with a nonce.
    let id: String
}
