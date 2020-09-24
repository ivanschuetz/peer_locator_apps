import XCTest
@testable import Match
import Combine

class DetectedBleDeviceFilterServiceTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        cancellables = []
    }

    func testBroadcastsValidatedDevice() {
        let uuid = UUID()
        let bleId = BleId(str: "123")!

        let expectedDevice = BleDetectedDevice(uuid: uuid, advertisementData: [:], rssi: NSNumber(integerLiteral: 0))

        let service: DetectedBleDeviceFilterService = DetectedBleDeviceFilterServiceImpl(
            deviceDetector: BleDeviceDetectorFixedDevice(device: expectedDevice),
            deviceValidator: BleDeviceValidatorServiceFixedDevices(devices: [uuid: bleId])
        )

        let exp = expectation(description: "All values received")

        service.device.sink(receiveValue: { peer in
            XCTAssertEqual(uuid, peer.deviceUuid)
            XCTAssertEqual(bleId, peer.id)
            // Note not testing complete object (BlePeer) as it needs rssi->distance calculation, out of scope right now.
            exp.fulfill()
        }).store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }
}
