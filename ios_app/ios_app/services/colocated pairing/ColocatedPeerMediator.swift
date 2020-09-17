import Foundation

protocol ColocatedPeerMediator {
    /**
     * Prepare my public key to be sent by protocol
     */
    func prepare(myPublicKey: PublicKey, password: ColocatedPeeringPassword) -> EncryptedPublicKey

    /**
     * Process peer's public key received by protocol
     */
    func processPeer(key: EncryptedPublicKey, password: ColocatedPeeringPassword) -> Peer?
}

class ColocatedPeerMediatorImpl: ColocatedPeerMediator {
    private let crypto: Crypto

    init(crypto: Crypto) {
        self.crypto = crypto
    }

    func prepare(myPublicKey: PublicKey, password: ColocatedPeeringPassword) -> EncryptedPublicKey {
        switch crypto.encrypt(str: myPublicKey.value, password: password.value) {
        case .success(let encryptedString):
            return EncryptedPublicKey(value: encryptedString)

        case .failure(let e):
            // TODO verify:
            // Assumption: encrypt can only fail because password has a not supported payload.
            // ColocatedPeeringPassword should make sure that the password is valid / the encryption always works.
            fatalError("Unexpected: \(e). Password encryption should always succeed. Password: \(password)")
        }
    }

    func processPeer(key: EncryptedPublicKey, password: ColocatedPeeringPassword) -> Peer? {
        switch crypto.decrypt(str: key.value, password: password.value) {
        case .success(let decryptedString):
            return Peer(publicKey: PublicKey(value: decryptedString))
        case .failure(let e):
            log.e("Error decrypting public key: \(e). Invalid?: \(key).", .cp)
            return nil
        }
    }
}
