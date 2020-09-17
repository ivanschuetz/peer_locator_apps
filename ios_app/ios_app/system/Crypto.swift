import Foundation
import CryptoKit

protocol Crypto {
    func createKeyPair() -> KeyPair

    func sign(privateKey: PrivateKey, payload: Data) -> Data
    func sign(privateKey: PrivateKey, payload: String) -> Data // Convenience

    func validate(payload: Data, signature: Data, publicKey: PublicKey) -> Bool
    func validate(payload: String, signature: Data, publicKey: PublicKey) -> Bool // Convenience

    func sha256(str: String) -> String

    // placeholder implementation. We'll use not use ColocatedPeeringPassword to encrypt
    // also, TODO: review password safety: write down what exactly we want to achive:
    // encryption, signing, verification? are we vulnerable to e.g. replay attack?
    // if we do want encryption, should we add a nonce?
    func encrypt(str: String, password: String) -> Result<String, ServicesError>
    func decrypt(str: String, password: String) -> Result<String, ServicesError>
}

class CryptoImpl: Crypto {

    func createKeyPair() -> KeyPair {
        let privateKey = P521.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        return KeyPair(privateKey: PrivateKey(value: privateKey.pemRepresentation),
                       publicKey: PublicKey(value: publicKey.pemRepresentation))
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

    func keyFromPassword(_ password: String) -> SymmetricKey {
        // TODO check if unwrap safe
        let hash = SHA256.hash(data: password.data(using: .utf8)!)
        // Convert the SHA256 to a string. This will be a 64 byte string
        let hashString = hash.map { String(format: "%02hhx", $0) }.joined()
        // Convert to 32 bytes
        let subString = String(hashString.prefix(32))
        // Convert the substring to data
        let keyData = subString.data(using: .utf8)!

        // Create the key use keyData as the seed
        return SymmetricKey(data: keyData)
    }

    func encrypt(str: String, password: String) -> Result<String, ServicesError> {
        return encrypt(str: str, key: keyFromPassword(password))
    }

    private func encrypt(str: String, key: SymmetricKey) -> Result<String, ServicesError> {
        // Convert to JSON in a Data record
//        let encoder = JSONEncoder()

        do {
//            let userData = try encoder.encode(str)

            let d = Data(str.utf8)

            // Encrypt the userData
            let encryptedData = try ChaChaPoly.seal(d, using: key)

//            let encryptedData = try ChaChaPoly.seal(userData, using: key)

            // Convert the encryptedData to a base64 string which is the
            // format that it can be transported in
            return .success(encryptedData.combined.base64EncodedString())

        } catch (let e) {
            return .failure(.general("Error encrypting string: \(e)"))
        }
    }

    func decrypt(str: String, password: String) -> Result<String, ServicesError> {
        return decrypt(str: str, key: keyFromPassword(password))
    }


    private func decrypt(str: String, key: SymmetricKey) -> Result<String, ServicesError> {
        // Convert the base64 string into a Data object
        let data = Data(base64Encoded: str)!

        do {
            // Put the data in a sealed box
            let box = try ChaChaPoly.SealedBox(combined: data)
            // Extract the data from the sealedbox using the decryption key
            let decryptedData = try ChaChaPoly.open(box, using: key)
            // The decrypted block needed to be json decoded
//            let decoder = JSONDecoder()
//            let object = try decoder.decode(type, from: decryptedData)

            if let decryptedString = String(data: decryptedData, encoding: .utf8) {
                return .success(decryptedString)
            } else {
                return .failure(.general("Decypted string was nil. data: \(decryptedData)"))
            }

        } catch (let e) {
            return .failure(.general("Error decrypting string: \(e)"))
        }


    }
}

private extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }
}
