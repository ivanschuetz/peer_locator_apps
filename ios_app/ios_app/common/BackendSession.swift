import Foundation

struct BackendSession {
    let id: SessionId
    let keys: [PublicKey]
}

struct PublicKey: Codable, Equatable {
    let value: String // P521 PEM representation
}

extension PublicKey {
    func toParticipantId(crypto: Crypto) -> ParticipantId {
        ParticipantId(value: crypto.sha256(str: value))
    }
}

struct PrivateKey: Codable {
    let value: String // P521 PEM representation
}


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

// TODO rename SessionData
struct MySessionData: Codable {
    let sessionId: SessionId
    let privateKey: PrivateKey
    // TODO (low prio): review: the own public key seems not necessary to store at the moment
    // it may help for debugging? Maybe remove in the future.
    let publicKey: PublicKey
    let participantId: ParticipantId
    let createdByMe: Bool
    let participant: Participant?

    func withParticipant(participant: Participant) -> MySessionData {
        MySessionData(
            sessionId: sessionId,
            privateKey: privateKey,
            publicKey: publicKey,
            participantId: participantId,
            createdByMe: createdByMe,
            participant: participant
        )
    }

    func isReady() -> Bool {
        participant != nil
    }
}

struct Participant: Codable {
    let publicKey: PublicKey
}

// Public key hash
struct ParticipantId: Codable {
    let value: String
}

struct Participants: Codable {
    let participants: [PublicKey]
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
