import Foundation
import CryptoKit

protocol Crypto {
    func createKeyPair() -> KeyPair

    func sign(privateKey: PrivateKey, payload: Data) -> Data
    func sign(privateKey: PrivateKey, payload: String) -> Data // Convenience

    func validate(payload: Data, signature: Data, publicKey: PublicKey) -> Bool
    func validate(payload: String, signature: Data, publicKey: PublicKey) -> Bool // Convenience

    func sha256(str: String) -> String
}

class CryptoImpl: Crypto {

    func createKeyPair() -> KeyPair {
        let privateKey = P521.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        return KeyPair(private_key: PrivateKey(value: privateKey.pemRepresentation),
                       public_key: PublicKey(value: publicKey.pemRepresentation))
    }

    func sign(privateKey: PrivateKey, payload: Data) -> Data {
        let p5121PrivateKey = try! P521.Signing.PrivateKey(pemRepresentation: privateKey.value)
        let signature = try! p5121PrivateKey.signature(for: payload)
        log.v("Signed: \(payload), privateKey: \(privateKey), signature: \(signature.rawRepresentation.toHex())")
        return signature.rawRepresentation
    }

    func sign(privateKey: PrivateKey, payload: String) -> Data {
        let data = payload.data(using: .utf8)!
        return sign(privateKey: privateKey, payload: data)
    }

    func validate(payload: Data, signature: Data, publicKey: PublicKey) -> Bool {
        let signingPublicKey = try! P521.Signing.PublicKey(pemRepresentation: publicKey.value)
        let p521Signature = try! P521.Signing.ECDSASignature(rawRepresentation: signature)
        let res = signingPublicKey.isValidSignature(p521Signature, for: payload)
        log.v("Validated payload: \(payload), signature: \(signature.toHex()), public key: \(publicKey), res: \(res)")
        return res
    }


    func validate(payload: String, signature: Data, publicKey: PublicKey) -> Bool {
        let data = payload.data(using: .utf8)!
        return validate(payload: data, signature: signature, publicKey: publicKey)
    }

    func sha256(str: String) -> String {
        // Force unwrap: used to hash keys, which should have always valid .utf8
        let data = str.data(using: .utf8)!
        return SHA256.hash(data: data).data.toHex()
    }

    //    func encrypt(myPrivateKey: PrivateKey, othersPublicKey: PublicKey, payload: SessionSignedPayload) {
    //        let p5121PrivateKey = try! P521.KeyAgreement.PrivateKey(pemRepresentation: myPrivateKey.value)
    //        let othersp5121PublicKey = try! P521.KeyAgreement.PublicKey(pemRepresentation: othersPublicKey.value)
    //        let sharedSecret: SharedSecret = try! p5121PrivateKey.sharedSecretFromKeyAgreement(with: othersp5121PublicKey)
    //    }
}

private extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }
}
