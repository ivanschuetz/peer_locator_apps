import Foundation

protocol ColocatedPeerMediator {
    func prepare(session: Session, password: ColocatedPeeringPassword) -> EncryptedPublicKey
    func processPeer(key: EncryptedPublicKey, password: ColocatedPeeringPassword) -> Peer?
}

class ColocatedPeerMediatorImpl: ColocatedPeerMediator {

    func prepare(session: Session, password: ColocatedPeeringPassword) -> EncryptedPublicKey {
        EncryptedPublicKey(value: crypto.encrypt(str: session.publicKey.value, key: password.value))
    }

    func processPeer(key: EncryptedPublicKey, password: ColocatedPeeringPassword) -> Peer? {
        guard let publicKeyValue = crypto.decrypt(str: key.value, key: password.value) else {
            log.e("Received an invalid peer public key: \(key). Exit.", .cp)
            return nil
        }
        return Peer(publicKey: PublicKey(value: publicKeyValue))
    }

    private let crypto: Crypto

    init(crypto: Crypto) {
        self.crypto = crypto
    }


}
