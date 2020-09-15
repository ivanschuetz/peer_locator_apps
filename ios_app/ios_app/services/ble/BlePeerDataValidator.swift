import Foundation

protocol BlePeerDataValidator {
    func validate(payload: SignedPeerPayload, peer: Peer) -> Bool
}

class BlePeerDataValidatorImpl: BlePeerDataValidator {
    private let crypto: Crypto

    init(crypto: Crypto) {
        self.crypto = crypto
    }

    func validate(payload: SignedPeerPayload, peer: Peer) -> Bool {
        let payloadToSign = payload.data

        log.v("Will validate peer payload: \(payload) with peer: \(peer)")

        // TODO unwrap safe here?
        let signData = Data(fromHexEncodedString: payload.sig)!

        return crypto.validate(payload: payloadToSign, signature: signData, publicKey: peer.publicKey)
    }
}
