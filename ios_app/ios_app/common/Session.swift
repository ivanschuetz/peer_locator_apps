import Foundation

struct Session {
    let id: SessionId
    let keys: [PublicKey]
}

struct PublicKey: Encodable, Decodable {
    let value: String // P521 PEM representation
}

struct PrivateKey: Encodable, Decodable {
    let value: String // P521 PEM representation
}

struct SessionId: Encodable, Decodable {
    let value: String
}

extension SessionId {
    func createLink() -> SessionLink {
        // remeet? vemeet?
        SessionLink(value: "rebond://\(value)")
    }
}

struct KeyPair {
    let private_key: PrivateKey
    let public_key: PublicKey
}

struct MySessionData: Encodable, Decodable {
    let sessionId: SessionId
    let privateKey: PrivateKey
    // TODO (low prio): review: the own public key seems not necessary to store at the moment
    // it may help for debugging? Maybe remove in the future.
    let publicKey: PublicKey
}

struct Participants: Encodable, Decodable {
    let participants: [PublicKey]
}

struct SessionLink {
    let value: String
}

extension SessionLink {
    func extractSessionId() -> Result<SessionId, ServicesError> {
        let comps = value.components(separatedBy: CharacterSet(charactersIn: "//"))
        // 1: schema, 2: empty string, 3: id
        if comps.count == 3 {
            return .success(SessionId(value: comps[2]))
        } else {
            return .failure(.general("Invalid session link: \(self)"))
        }
    }
}

struct SessionSignedPayload: Encodable, Decodable {
    // For now a red herring. Normally we should encrypt, with a nonce.
    let id: String
}

struct SharedSessionData {
    let id: SessionId
    let isReady: SessionReady
}

// TODO maybe replace with SessionStatus { ready, notReady } ?
enum SessionReady {
    case yes, no
}
