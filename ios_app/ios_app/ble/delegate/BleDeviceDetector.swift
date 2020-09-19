import CoreBluetooth
import Combine

protocol BleDeviceDetector {
    var discovered: AnyPublisher<BleDetectedDevice, Never> { get }
}

class BleDeviceDetectorImpl: BleDeviceDetector {
    let discoveredSubject = PassthroughSubject<BleDetectedDevice, Never>()
    lazy var discovered = discoveredSubject.eraseToAnyPublisher()
}

extension BleDeviceDetectorImpl: BleCentralDelegate {

    func onDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        discoveredSubject.send(BleDetectedDevice(uuid: peripheral.identifier,
                                                 advertisementData: advertisementData,
                                                 rssi: rssi))
    }

    func onDiscoverCaracteristics(_ characteristics: [CBCharacteristic], peripheral: CBPeripheral, error: Error?) -> Bool {
        return false
    }

    func onReadCharacteristic(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) -> Bool {
        return false
    }

    func onWriteCharacteristicAck(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) {}
}
