import Foundation

protocol BleValidationDataMediator {
    func prepare(privateKey: PrivateKey) -> BleId?
    func process(bleId: BleId) -> Result<SignedPeerPayload, ServicesError>
}

class BleValidationDataMediatorImpl: BleValidationDataMediator {
    private let crypto: Crypto
    private let json: Json

    init(crypto: Crypto, json: Json) {
        self.crypto = crypto
        self.json = json
    }

    func prepare(privateKey: PrivateKey) -> BleId? {
        // Some data to be signed
        // We don't need this data directly: we're just interested in verifying the user, i.e. the signature
        // TODO(pandroid) actual random string. For now hardcoded for easier debugging.
        // this is anyway a temporary solution. We want to send encrypted (with peer's public key) json (with an index)
        let randomString = "randomString"

        guard let payloadToSignStr = json.toJson(encodable: SessionPayloadToSign(id: randomString)).asOptional() else {
            log.e("Can't generate Ble id. Couldn't convert session payload to JSON", .ble)
            return nil
        }

        // Create our signature
        let signature = crypto.sign(privateKey: privateKey, payload: payloadToSignStr)
        let signatureStr = signature.toHex()

        // The total data sent to peers: "data"(useless) with the corresponding signature
        let payload = SignedPeerPayload(data: payloadToSignStr, sig: signatureStr)

        guard let payloadStr = json.toJson(encodable: payload).asOptional() else {
            log.e("Can't generate Ble id. Can't convert payload: \(payload) to JSON", .ble)
            return nil
        }

        // Unwrap: inputs: hardcoded random string json and hex representation of signature -> always utf8
        return BleId(data: payloadStr.data(using: .utf8)!)
    }

    func process(bleId: BleId) -> Result<SignedPeerPayload, ServicesError> {
        let dataStr = bleId.str()
        return json.fromJson(json: dataStr)
    }
}

