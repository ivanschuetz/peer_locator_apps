import Foundation

protocol ColocatedPeerMediator {
    func prepare(session: Session, password: ColocatedPeeringPassword) -> EncryptedPublicKey
    func processPeer(key: EncryptedPublicKey, password: ColocatedPeeringPassword) -> Participant?
}

class ColocatedPeerMediatorImpl: ColocatedPeerMediator {

    func prepare(session: Session, password: ColocatedPeeringPassword) -> EncryptedPublicKey {
        EncryptedPublicKey(value: crypto.encrypt(str: session.publicKey.value, key: password.value))
    }

    func processPeer(key: EncryptedPublicKey, password: ColocatedPeeringPassword) -> Participant? {
        guard let publicKeyValue = crypto.decrypt(str: key.value, key: password.value) else {
            log.e("Received an invalid peer public key: \(key). Exit.", .cp)
            return nil
        }
        return Participant(publicKey: PublicKey(value: publicKeyValue))
    }

    private let crypto: Crypto

    init(crypto: Crypto) {
        self.crypto = crypto
    }


}
