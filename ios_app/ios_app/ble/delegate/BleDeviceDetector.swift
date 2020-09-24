import CoreBluetooth
import Combine

/**
 * Broadcasts all detected peripherals, with their advertisement data and RSSI.
 */
protocol BleDeviceDetector: BleCentralDelegate {
    var discovered: AnyPublisher<BleDetectedDevice, Never> { get }
}

class BleDeviceDetectorImpl: BleDeviceDetector {
    let discoveredSubject = PassthroughSubject<BleDetectedDevice, Never>()
    lazy var discovered = discoveredSubject.eraseToAnyPublisher()
}

extension BleDeviceDetectorImpl {

    func onDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
//        log.v("Detected a peripheral: \(peripheral.identifier), rssi: \(rssi)", .ble)
        discoveredSubject.send(BleDetectedDevice(uuid: peripheral.identifier,
                                                 advertisementData: advertisementData,
                                                 rssi: rssi))
    }

    func onDiscoverCaracteristics(_ characteristics: [CBCharacteristic], peripheral: CBPeripheral, error: Error?) -> Bool {
        false
    }

    func onReadCharacteristic(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) -> Bool {
        false
    }

    func onWriteCharacteristicAck(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) {}
}
