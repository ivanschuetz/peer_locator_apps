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

struct SessionSignedPayload: Encodable, Decodable {
    let sessionId: String
    let name: String
    let nonce: String
}
