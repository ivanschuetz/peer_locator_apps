import Foundation

// TODO probably has to be abstracted to include Nearby id too
protocol BleIdService {
    func id() -> BleId?
    func validate(bleId: BleId) -> Bool
}

class BleIdServiceImpl: BleIdService {
    private let crypto: Crypto
    private let json: Json
    private let sessionStore: SessionStore
    private let keyChain: KeyChain

    init(crypto: Crypto, json: Json, sessionStore: SessionStore, keyChain: KeyChain) {
        self.crypto = crypto
        self.json = json
        self.sessionStore = sessionStore
        self.keyChain = keyChain
    }

    func id() -> BleId? {
        let sessionDataRes: Result<MySessionData?, ServicesError> = keyChain.getDecodable(key: .mySessionData)
        switch sessionDataRes {
        case .success(let sessionData):
            if let sessionData = sessionData {
                return id(sessionData: sessionData)
            } else {
                // This state is valid as devices can be close and with ble services (central/peripheral) on
                // without session data: we are in this state during colocated pairing
                // id == nil here means essentially "not yet paired".
                // TODO probably we should block reading session data during colocated pairing / non-active session
                log.v("There's no session data. Can't generate Ble id (TODO see comment)", .ble)
                return nil
            }
        case .failure(let e):
            // TODO handling
            log.e("Critical: couldn't retrieve my session data: (\(e)). Can't generate Ble id", .ble)
            return nil
        }
    }

    private func id(sessionData: MySessionData) -> BleId? {
        // Some data to be signed
        // We don't need this data directly: we're just interested in verifying the user, i.e. the signature
        // TODO actual random string. For now hardcoded for easier debugging.
        // this is anyway a temporary solution. We want to send encrypted (with peer's public key) json (with an index)
        let randomString = "randomString"

        let payloadToSignStr = json.toJson(encodable: SessionPayloadToSign(id: randomString))

        // Create our signature
        let signature = crypto.sign(privateKey: sessionData.privateKey,
                                    payload: payloadToSignStr)
        let signatureStr = signature.toHex()

        // The total data sent to participants: "data"(useless) with the corresponding signature
        let payload = SignedParticipantPayload(data: payloadToSignStr, sig: signatureStr)
        let payloadStr = json.toJson(encodable: payload)
        return BleId(data: payloadStr.data(using: .utf8)!)
    }

    func validate(bleId: BleId) -> Bool {
        // TODO consider commenting this when going to production
        // it's very unlikely that there will be iphones with x86, but it's a serious security risk.
        #if arch(x86_64)
        if String(data: bleId.data, encoding: .utf8) == "fakesimulatorid" {
            return true
        }
        #endif

        log.d("Will validate: \(bleId)", .val)
        switch sessionStore.getSession() {
        case .success(let session):
            if let session = session {
                if let participant = session.participant {
                    let res = validate(bleId: bleId, participant: participant)
                    log.d("Validation result: \(res)", .val)
                    return res
                } else {
                    log.e("Invalid state?: validating, but session has no peer yet: \(bleId)", .val)
                    return false
                }
            } else {
                log.e("Invalid state?: validating, but no current session. bleId: \(bleId)", .val)
                return false
            }
        case .failure(let e):
            log.e("Error retrieving participants: \(e), returning validate = false", .val)
            return false
        }
    }

    private func validate(bleId: BleId, participant: Participant) -> Bool {
        let dataStr = bleId.str()

        let signedParticipantPayload: SignedParticipantPayload = json.fromJson(json: dataStr)
        let payloadToSign = signedParticipantPayload.data

        log.v("Will validate participant payload: \(signedParticipantPayload) with participant: \(participant)")

        let signData = Data(fromHexEncodedString: signedParticipantPayload.sig)!

        return crypto.validate(payload: payloadToSign, signature: signData, publicKey: participant.publicKey)
    }
}

struct SignedParticipantPayload: Codable {
    let data: String // random
    let sig: String
}

class BleIdServiceNoop: BleIdService {
    func id() -> BleId? {
        nil
    }

    func validate(bleId: BleId) -> Bool {
        false
    }
}
