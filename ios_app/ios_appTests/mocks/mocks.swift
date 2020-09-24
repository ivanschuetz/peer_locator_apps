import Foundation
@testable import Match
import Combine
import CoreBluetooth

/**
 * Fakes a given detected peer (validation characteristic read)
 */
class BleValidationFixedPeer: BleValidation {
    let read: AnyPublisher<BlePeer, Never>
    let errorReadingValidation: AnyPublisher<Error, Never> = Empty().eraseToAnyPublisher()

    init(uuid: UUID, bleId: BleId) {
        read = Just(BlePeer(deviceUuid: uuid, id: bleId, distance: 0)).eraseToAnyPublisher()
    }

    // Note: this is not validation, it's just sending the validation read request
    func validatePeer() -> Bool {
        return true
    }
}

/**
 * Validation always succeeds
 */
class BleIdServiceValidationAlwaysSucceeds: BleIdService {
    // Irrelevant. Maybe we should split the protocol.
    func id() -> BleId? {
        nil
    }

    func validate(bleId: BleId) -> Bool {
        true
    }
}

class BleDeviceDetectorFixedDevice: BleDeviceDetector {
    let device: BleDetectedDevice

    init(device: BleDetectedDevice) {
        self.device = device
    }

    lazy var discovered: AnyPublisher<BleDetectedDevice, Never> = Just(device).eraseToAnyPublisher()

    func onDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {}

    func onReadCharacteristic(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) -> Bool {
        false
    }

    func onWriteCharacteristicAck(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) {}

    func onDiscoverCaracteristics(_ characteristics: [CBCharacteristic], peripheral: CBPeripheral, error: Error?) -> Bool {
        false
    }
}

class BleDeviceValidatorServiceFixedDevices: BleDeviceValidatorService {
    let validDevices: AnyPublisher<[UUID: BleId], Never>
    init(devices: [UUID: BleId]) {
        validDevices = Just(devices).eraseToAnyPublisher()
    }
}
