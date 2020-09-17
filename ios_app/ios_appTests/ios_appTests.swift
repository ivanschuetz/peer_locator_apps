import XCTest
@testable import Match
import CryptoKit

class ios_appTests: XCTestCase {

    func testValidatesSignature() {
        let crypto = CryptoImpl()

        let privateKeyStr = """
        -----BEGIN PRIVATE KEY-----
        MIHuAgEAMBAGByqGSM49AgEGBSuBBAAjBIHWMIHTAgEBBEIB9nXNomrZfPyRdNkJ
        7fDpcKis0W+PWFOktCW6k00sLZsYtjGKldVFDGWXD4hGDW0xmNSTUTEuBof7/g8i
        cxbjSMShgYkDgYYABAAOTOxdEU4KN3GX8hiNBtj40udMJMi9dUflyll4j1eCWh51
        t1MDil0m1a8i7slUIxgCVAXrEp4n8esNOb0VFnymHwA+HTq8lz76GbMP3RwFmgNI
        9EPuA4bIIplrvsdyNEsUEi/4sN2rcA+cZt2Xq/c8MrOIB0BmNZpwhy7teY2S4ErN
        wA==
        -----END PRIVATE KEY-----
        """

        let publicKeyStr = """
        -----BEGIN PUBLIC KEY-----
        MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQADkzsXRFOCjdxl/IYjQbY+NLnTCTI
        vXVH5cpZeI9XgloedbdTA4pdJtWvIu7JVCMYAlQF6xKeJ/HrDTm9FRZ8ph8APh06
        vJc++hmzD90cBZoDSPRD7gOGyCKZa77HcjRLFBIv+LDdq3APnGbdl6v3PDKziAdA
        ZjWacIcu7XmNkuBKzcA=
        -----END PUBLIC KEY-----
        """

        let privateKey = PrivateKey(value: privateKeyStr)
        let publicKey = PublicKey(value: publicKeyStr)

        let payload = "randomString"

        let signature = crypto.sign(privateKey: privateKey, payload: payload)

        XCTAssertTrue(crypto.validate(payload: payload, signature: signature, publicKey: publicKey))
    }

    func testSerializationOfNearbyTokenWorks() {
        let crypto = CryptoImpl()
        let json = JsonImpl()

        let privateKeyStr = """
        -----BEGIN PRIVATE KEY-----
        MIHuAgEAMBAGByqGSM49AgEGBSuBBAAjBIHWMIHTAgEBBEIB9nXNomrZfPyRdNkJ
        7fDpcKis0W+PWFOktCW6k00sLZsYtjGKldVFDGWXD4hGDW0xmNSTUTEuBof7/g8i
        cxbjSMShgYkDgYYABAAOTOxdEU4KN3GX8hiNBtj40udMJMi9dUflyll4j1eCWh51
        t1MDil0m1a8i7slUIxgCVAXrEp4n8esNOb0VFnymHwA+HTq8lz76GbMP3RwFmgNI
        9EPuA4bIIplrvsdyNEsUEi/4sN2rcA+cZt2Xq/c8MrOIB0BmNZpwhy7teY2S4ErN
        wA==
        -----END PRIVATE KEY-----
        """

        let dataStr = "foobar123"

        let token = NearbyToken(data: dataStr.data(using: .utf8)!)

        let signature = crypto.sign(privateKey: PrivateKey(value: privateKeyStr), payload: token.data)
        let signedToken = SignedNearbyToken(token: token, sig: signature)
        let serializedToken = SerializedSignedNearbyToken(data: json.toJsonData(encodable: signedToken))

        let deserializedSignedNearbyToken: SignedNearbyToken = json.fromJsonData(json: serializedToken.data)

        XCTAssertEqual(signedToken, deserializedSignedNearbyToken)
        // Double checking (probably not necessary) that the string is correct
        XCTAssertEqual(dataStr, String(data: deserializedSignedNearbyToken.data, encoding: .utf8)!)
    }

    func testValidatesNearbyTokenSignature() {
        let crypto = CryptoImpl()
        let json = JsonImpl()

        let privateKeyStr = """
        -----BEGIN PRIVATE KEY-----
        MIHuAgEAMBAGByqGSM49AgEGBSuBBAAjBIHWMIHTAgEBBEIB9nXNomrZfPyRdNkJ
        7fDpcKis0W+PWFOktCW6k00sLZsYtjGKldVFDGWXD4hGDW0xmNSTUTEuBof7/g8i
        cxbjSMShgYkDgYYABAAOTOxdEU4KN3GX8hiNBtj40udMJMi9dUflyll4j1eCWh51
        t1MDil0m1a8i7slUIxgCVAXrEp4n8esNOb0VFnymHwA+HTq8lz76GbMP3RwFmgNI
        9EPuA4bIIplrvsdyNEsUEi/4sN2rcA+cZt2Xq/c8MrOIB0BmNZpwhy7teY2S4ErN
        wA==
        -----END PRIVATE KEY-----
        """

        let publicKeyStr = """
        -----BEGIN PUBLIC KEY-----
        MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQADkzsXRFOCjdxl/IYjQbY+NLnTCTI
        vXVH5cpZeI9XgloedbdTA4pdJtWvIu7JVCMYAlQF6xKeJ/HrDTm9FRZ8ph8APh06
        vJc++hmzD90cBZoDSPRD7gOGyCKZa77HcjRLFBIv+LDdq3APnGbdl6v3PDKziAdA
        ZjWacIcu7XmNkuBKzcA=
        -----END PUBLIC KEY-----
        """

        let token = NearbyToken(data: "foobar123".data(using: .utf8)!)

        let signature = crypto.sign(privateKey: PrivateKey(value: privateKeyStr), payload: token.data)
        let signedToken = SignedNearbyToken(token: token, sig: signature)
        let serializedToken = SerializedSignedNearbyToken(data: json.toJsonData(encodable: signedToken))

        let deserializedSignedNearbyToken: SignedNearbyToken = json.fromJsonData(json: serializedToken.data)

        XCTAssertTrue(crypto.validate(payload: deserializedSignedNearbyToken.data,
                                      signature: deserializedSignedNearbyToken.sig,
                                      publicKey: PublicKey(value: publicKeyStr)))
    }

    func testPasswordEncryption() {
        let crypto = CryptoImpl()

        let publicKeyStr = """
        -----BEGIN PUBLIC KEY-----
        MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQADkzsXRFOCjdxl/IYjQbY+NLnTCTI
        vXVH5cpZeI9XgloedbdTA4pdJtWvIu7JVCMYAlQF6xKeJ/HrDTm9FRZ8ph8APh06
        vJc++hmzD90cBZoDSPRD7gOGyCKZa77HcjRLFBIv+LDdq3APnGbdl6v3PDKziAdA
        ZjWacIcu7XmNkuBKzcA=
        -----END PUBLIC KEY-----
        """

        let password = "test123"

        let encryptRes: Result<String, ServicesError> = crypto.encrypt(str: publicKeyStr, password: password)
        XCTAssertFalse(encryptRes.isFailure())

        let encryptedStr: String = try! encryptRes.get()

        let decryptRes: Result<String, ServicesError> = crypto.decrypt(str: encryptedStr, password: password)
        XCTAssertFalse(decryptRes.isFailure())

        let decryptedStr: String = try! decryptRes.get()
        XCTAssertEqual(decryptedStr, publicKeyStr)
    }

    func testColocatedPeerMediator() {
        let crypto = CryptoImpl()
        let mediator = ColocatedPeerMediatorImpl(crypto: crypto)

        let publicKeyStr = """
        -----BEGIN PUBLIC KEY-----
        MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQADkzsXRFOCjdxl/IYjQbY+NLnTCTI
        vXVH5cpZeI9XgloedbdTA4pdJtWvIu7JVCMYAlQF6xKeJ/HrDTm9FRZ8ph8APh06
        vJc++hmzD90cBZoDSPRD7gOGyCKZa77HcjRLFBIv+LDdq3APnGbdl6v3PDKziAdA
        ZjWacIcu7XmNkuBKzcA=
        -----END PUBLIC KEY-----
        """

        let publicKey = PublicKey(value: publicKeyStr)
        let password = ColocatedPeeringPassword(value: "test123")

        let encryptedPublicKey = mediator.prepare(myPublicKey: publicKey, password: password)

        let decryptedPublicKeyPeer = mediator.processPeer(key: encryptedPublicKey, password: password)

        XCTAssertNotNil(decryptedPublicKeyPeer)
        XCTAssertEqual(decryptedPublicKeyPeer!.publicKey, publicKey)
    }

    func testGreet() {
        let res = greet("Ivan")!.takeRetainedValue() as String
        XCTAssertEqual("Hello 👋 Ivan!", res)
    }

    func testAdd() {
        let res = add_values(1, 2)
        XCTAssertEqual(3, res)
    }

    func testPassStruct() {
        var myStruct = ParamStruct(string: NSString(string: "foo").utf8String, int_: 1)
        let structPointer = withUnsafeMutablePointer(to: &myStruct) {
            UnsafeMutablePointer<ParamStruct>($0)
        }
        pass_struct(structPointer)
        // There's no result. Only testing that it doesn't crash.
    }

    func testReturnStruct() {
        let res = return_struct()

        let unmanagedString: Unmanaged<CFString> = res.string
        let cfStr: CFString = unmanagedString.takeRetainedValue()
        let str = cfStr as String

        XCTAssertEqual(str, "my string parameter")
        XCTAssertEqual(res.int_, 123)
    }

    func testRegistersCallback() {
        register_callback { (string: CFString?) in
            let cfStr: CFString = string!
            let str = cfStr as String
            XCTAssertEqual(str, "Hello callback!")
        }
    }
}
