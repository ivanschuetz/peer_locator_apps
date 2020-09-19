import CoreBluetooth
import Combine

class BleColocatedPairing {
    private let characteristicUuid = CBUUID(string: "0be778a3-2096-46c8-82c9-3a9d63376514")
    lazy var publicKey = publicKeySubject.compactMap{ $0 }.eraseToAnyPublisher()

    let discoveredSubject = PassthroughSubject<BlePeer, Never>()
    lazy var discovered = discoveredSubject.eraseToAnyPublisher()

    private let publicKeySubject = CurrentValueSubject<SerializedEncryptedPublicKey?, Never>(nil)

    private var peripheral: CBPeripheral?

    private var discoveredCharacteristic: CBCharacteristic?

    // TODO confirm: is the peripheral reliably available here? Probably we should use reactive
    // instead, with poweredOn + write?
    func write(publicKey: SerializedEncryptedPublicKey) -> Bool {
        guard let peripheral = peripheral else {
            log.e("Attempted to write, but peripheral is not set.", .ble)
            return false
        }
        guard let characteristic = discoveredCharacteristic else {
            log.e("Attempted to write, but colocated public key characteristic is not set.", .ble)
            return false
        }
        log.d("Writing public key to colocated characteristic", .ble)
        peripheral.writeValue(publicKey.data, for: characteristic, type: .withResponse)
        return true
    }
}

extension BleColocatedPairing: BlePeripheralDelegateWriteOnly {

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
        publicKeySubject.send(SerializedEncryptedPublicKey(data: data))
    }
}

extension BleColocatedPairing: BleCentralDelegate {

    func onDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        self.peripheral = peripheral
    }

    func onDiscoverCaracteristics(_ characteristics: [CBCharacteristic], peripheral: CBPeripheral,
                                  error: Error?) -> Bool {
        if let discoveredCharacteristic = characteristics.first(where: {
            $0.uuid == characteristicUuid
        }) {
            log.d("Setting the colocated pairing characteristic", .ble)
            self.discoveredCharacteristic = discoveredCharacteristic
            return true

        } else {
            log.e("Service doesn't have colocated characteristic.", .ble)
            return false
        }
    }


    func onReadCharacteristic(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) -> Bool {
        if characteristic.uuid == characteristicUuid {
            fatalError("We don't read colocated characteristic")
        }
        return false
    }

    func onWriteCharacteristicAck(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) {
        guard characteristic.uuid == characteristicUuid else { return }

        if let error = error {
            log.e("Error: \(error) writing characteristic: \(characteristic)", .ble)
            // TODO investigate: do we need to implement retry
        } else {
            log.d("Successfully wrote characteristic: \(characteristic)", .ble)
        }
    }
}
