import Foundation

protocol NearbyTokenProcessor {
    func prepareToSend(token: NearbyToken, privateKey: PrivateKey) -> SerializedSignedNearbyToken
    func validate(token: SerializedSignedNearbyToken, publicKey: PublicKey) -> NearbyTokenValidationResult
}

class NearbyTokenProcessorImpl: NearbyTokenProcessor {
    private let crypto: Crypto
    private let json: Json

    init(crypto: Crypto, json: Json) {
        self.crypto = crypto
        self.json = json
    }

    func prepareToSend(token: NearbyToken, privateKey: PrivateKey) -> SerializedSignedNearbyToken {
        let signature = crypto.sign(privateKey: privateKey, payload: token.data)
        let signedToken = SignedNearbyToken(token: token, sig: signature)
        return SerializedSignedNearbyToken(data: json.toJsonData(encodable: signedToken))
    }

    func validate(token serializedToken: SerializedSignedNearbyToken,
                  publicKey: PublicKey) -> NearbyTokenValidationResult {
        let token = deserialize(token: serializedToken)
        if validate(token: deserialize(token: serializedToken), publicKey: publicKey) {
            return .valid(token: NearbyToken(data: token.data))
        } else {
            return .invalid
        }
    }

    private func deserialize(token: SerializedSignedNearbyToken) -> SignedNearbyToken {
        json.fromJsonData(json: token.data)
    }

    private func validate(token: SignedNearbyToken, publicKey: PublicKey) -> Bool {
        crypto.validate(payload: token.data, signature: token.sig, publicKey: publicKey)
    }
}

enum NearbyTokenValidationResult {
    case valid(token: NearbyToken)
    case invalid
}
