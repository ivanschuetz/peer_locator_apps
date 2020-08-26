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
