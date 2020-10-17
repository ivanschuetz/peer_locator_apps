import Foundation

protocol NearbyTokenProcessor {
    func prepareToSend(token: NearbyToken,
                       privateKey: PrivateKey) -> Result<SerializedSignedNearbyToken, ServicesError>
    
    func validate(token: SerializedSignedNearbyToken,
                  publicKey: PublicKey) -> Result<NearbyTokenValidationResult, ServicesError>
}

class NearbyTokenProcessorImpl: NearbyTokenProcessor {
    private let crypto: Crypto
    private let json: Json

    init(crypto: Crypto, json: Json) {
        self.crypto = crypto
        self.json = json
    }

    func prepareToSend(token: NearbyToken, privateKey: PrivateKey) -> Result<SerializedSignedNearbyToken, ServicesError> {
        let signature = crypto.sign(privateKey: privateKey, payload: token.data)
        let signedToken = SignedNearbyToken(token: token, sig: signature)
        return json.toJsonData(encodable: signedToken).map {
            SerializedSignedNearbyToken(data: $0)
        }
    }

    func validate(token serializedToken: SerializedSignedNearbyToken,
                  publicKey: PublicKey) -> Result<NearbyTokenValidationResult, ServicesError> {
        deserialize(token: serializedToken).map { token in
            if validate(token: token, publicKey: publicKey) {
                return .valid(token: NearbyToken(data: token.data))
            } else {
                return .invalid
            }
        }
    }

    private func deserialize(token: SerializedSignedNearbyToken) -> Result<SignedNearbyToken, ServicesError> {
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
