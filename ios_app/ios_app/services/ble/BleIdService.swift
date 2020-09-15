import Foundation

// TODO probably has to be abstracted to include Nearby id too
protocol BleIdService {
    func id() -> BleId?
    func validate(bleId: BleId) -> Bool
}

class BleIdServiceImpl: BleIdService {
    private let localSessionManager: LocalSessionManager
    private let validationDataMediator: BleValidationDataMediator
    private let peerValidator: BlePeerDataValidator

    init(localSessionManager: LocalSessionManager,
         validationDataMediator: BleValidationDataMediator,
         peerValidator: BlePeerDataValidator) {
        self.localSessionManager = localSessionManager
        self.validationDataMediator = validationDataMediator
        self.peerValidator = peerValidator
    }

    func id() -> BleId? {
        switch localSessionManager.getSession() {
        case .success(let session):
            if let session = session {
                return validationDataMediator.prepare(privateKey: session.privateKey)
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

    func validate(bleId: BleId) -> Bool {
        // TODO consider commenting this when going to production
        // it's very unlikely that there will be iphones with x86, but it's a serious security risk.
        #if arch(x86_64)
        if String(data: bleId.data, encoding: .utf8) == "fakesimulatorid" {
            return true
        }
        #endif

        log.d("Will validate: \(bleId)", .val)
        switch localSessionManager.getSession() {
        case .success(let session):
            if let session = session {
                if let peer = session.peer {
                    let res = validate(bleId: bleId, peer: peer)
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
            log.e("Error retrieving peers: \(e), returning validate = false", .val)
            return false
        }
    }

    private func validate(bleId: BleId, peer: Peer) -> Bool {
        let signedPeerPayload: SignedPeerPayload = validationDataMediator.process(bleId: bleId)
        return peerValidator.validate(payload: signedPeerPayload, peer: peer)
    }
}

struct SignedPeerPayload: Codable {
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
