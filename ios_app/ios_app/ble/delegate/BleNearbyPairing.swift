import CoreBluetooth
import Combine

protocol NearbyPairing {
    var token: AnyPublisher<SerializedSignedNearbyToken, Never> { get }
    
    func sendDiscoveryToken(token: SerializedSignedNearbyToken)
}

class BleNearbyPairing: NearbyPairing {
    private let tokenSubject = CurrentValueSubject<SerializedSignedNearbyToken?, Never>(nil)
    lazy var token = tokenSubject.compactMap{ $0 }.eraseToAnyPublisher()

    private let characteristicUuid = CBUUID(string: "0be778a3-2096-46c8-82c9-3a9d63376513")

    private var peripheral: CBPeripheral?

    private var discoveredCharacteristic: CBCharacteristic?

    func sendDiscoveryToken(token: SerializedSignedNearbyToken) {
        guard let peripheral = peripheral else {
            log.e("Attempted to write, but peripheral is not set.", .ble)
            return
        }
        guard let characteristic = discoveredCharacteristic else {
            log.e("Attempted to write, but nearby characteristic is not set.", .ble)
            return
        }
        peripheral.writeValue(token.data, for: characteristic, type: .withResponse)
    }
}

extension BleNearbyPairing: BlePeripheralDelegateWriteOnly {

    var characteristic: CBMutableCharacteristic {
        CBMutableCharacteristic(
            type: characteristicUuid,
            properties: [.write],
            value: nil,
            // TODO what is .writeEncryptionRequired / .readEncryptionRequired? does it help us?
            permissions: [.writeable]
        )
    }

    func handleWrite(data: Data) {
        tokenSubject.send(SerializedSignedNearbyToken(data: data))
    }
}

extension BleNearbyPairing: BleCentralDelegate {

    func onDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        self.peripheral = peripheral
    }

    func onDiscoverCaracteristics(_ characteristics: [CBCharacteristic], peripheral: CBPeripheral,
                                  error: Error?) -> Bool {
        if let discoveredCharacteristic = characteristics.first(where: {
            $0.uuid == characteristicUuid
        }) {
            log.d("Setting the nearby characteristic", .ble)
            self.discoveredCharacteristic = discoveredCharacteristic
            return true

        } else {
            log.e("Service doesn't have nearby characteristic.", .ble)
            return false
        }
    }

    func onReadCharacteristic(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) -> Bool {
        if characteristic.uuid == characteristicUuid {
            fatalError("We don't read nearby characteristic")
        }
        return false
    }
}
