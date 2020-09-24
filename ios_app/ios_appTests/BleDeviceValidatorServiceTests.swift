import XCTest
@testable import Match
import Combine

class BleDeviceValidatorServiceTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        cancellables = []
    }

    func testDeviceValidatorServiceImplSavesValidDeviceInDictionary() {
        let uuid = UUID()
        let bleId = BleId(str: "123")!

        let service = BleDeviceValidatorServiceImpl(bleValidation: BleValidationFixedPeer(uuid: uuid, bleId: bleId),
                                                    idService: BleIdServiceValidationAlwaysSucceeds())
        let expected = [uuid: bleId]

        let exp = expectation(description: "All values received")

        service.validDevices.sink(receiveValue: { value in
            XCTAssertEqual(expected, value)
            exp.fulfill()
        }).store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }
}
