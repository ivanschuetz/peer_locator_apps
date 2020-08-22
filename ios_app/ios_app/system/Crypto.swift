import Foundation
import CryptoKit

protocol Crypto {
    func createKeyPair() -> KeyPair
    func sign(privateKey: PrivateKey, payload: SessionSignedPayload) -> Data
    func validate(data: Data, signature: Data, publicKey: PublicKey) -> Bool
}

class CryptoImpl: Crypto {
    private let json: Json
    init(json: Json) {
        self.json = json
    }

    func createKeyPair() -> KeyPair {
        let privateKey = P521.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        return KeyPair(private_key: PrivateKey(value: privateKey.pemRepresentation),
                       public_key: PublicKey(value: publicKey.pemRepresentation))
    }

    func sign<T: Encodable>(privateKey: PrivateKey, payload: T) -> Data {
        let p5121PrivateKey = try! P521.Signing.PrivateKey(pemRepresentation: privateKey.value)
        let data = json.toJson(encodable: payload).data(using: .utf8)!
        let signature = try! p5121PrivateKey.signature(for: data)
        return signature.rawRepresentation
    }

    func validate(data: Data, signature: Data, publicKey: PublicKey) -> Bool {
        let signingPublicKey = try! P521.Signing.PublicKey(pemRepresentation: publicKey.value)
        let p521Signature = try! P521.Signing.ECDSASignature(rawRepresentation: signature)
        return signingPublicKey.isValidSignature(p521Signature, for: data)
    }

    //    func encrypt(myPrivateKey: PrivateKey, othersPublicKey: PublicKey, payload: SessionSignedPayload) {
    //        let p5121PrivateKey = try! P521.KeyAgreement.PrivateKey(pemRepresentation: myPrivateKey.value)
    //        let othersp5121PublicKey = try! P521.KeyAgreement.PublicKey(pemRepresentation: othersPublicKey.value)
    //        let sharedSecret: SharedSecret = try! p5121PrivateKey.sharedSecretFromKeyAgreement(with: othersp5121PublicKey)
    //    }
}
