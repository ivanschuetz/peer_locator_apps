import CoreBluetooth
import Combine

protocol BleColocatedPairing: BlePeripheralDelegate, BleCentralDelegate {
    var publicKey: AnyPublisher<SerializedEncryptedPublicKey, Never> { get }
    var errorSendingKey: AnyPublisher<Error, Never> { get }

    func write(publicKey: SerializedEncryptedPublicKey) -> Bool
}

class BleColocatedPairingImpl: BleColocatedPairing {
    private let characteristicUuid = CBUUID(string: "0be778a3-2096-46c8-82c9-3a9d63376514")

    let discoveredSubject = PassthroughSubject<BlePeer, Never>()
    lazy var discovered = discoveredSubject.eraseToAnyPublisher()

    private let errorSendingKeySubject = PassthroughSubject<Error, Never>()
    lazy var errorSendingKey = errorSendingKeySubject.compactMap{ $0 }.eraseToAnyPublisher()

    private let publicKeySubject = CurrentValueSubject<SerializedEncryptedPublicKey?, Never>(nil)
    lazy var publicKey = publicKeySubject.compactMap{ $0 }.eraseToAnyPublisher()

    private var peripheral: CBPeripheral?

    private var discoveredCharacteristic: CBCharacteristic?

    private var retry: RetryData<SerializedEncryptedPublicKey>?

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

extension BleColocatedPairingImpl: BlePeripheralDelegateWriteOnly {

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

extension BleColocatedPairingImpl: BleCentralDelegate {

    func onConnectPeripheral(_ peripheral: CBPeripheral) {
        self.peripheral = peripheral
    }

    func onDidFailToConnectToPeripheral(_ peripheral: CBPeripheral) {}

    func onDisconnectPeripheral(_ peripheral: CBPeripheral) {
        self.peripheral = nil
    }

    func onDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {}

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
            handleWriteError(error)
        } else {
            retry = nil
            log.d("Successfully wrote characteristic: \(characteristic)", .ble)
        }
    }

    private func handleWriteError(_ error: Error) {
        log.e("Error: \(error) writing colocated key: \(characteristic)", .ble)
        if let retry = retry {
            if retry.shouldRetry() {
                log.d("Retrying colocated key write. Attempt: \(retry.count)", .ble)
                self.retry = retry.increment()
                _ = write(publicKey: retry.data)
            } else {
                log.d("Failed colocated key write after \(retry.count) attempts. Error.", .ble)
                errorSendingKeySubject.send(error)
            }
        } else {
            log.e("Illegal state? retry should be set when receiving ack", .ble)
            errorSendingKeySubject.send(error)
        }
    }
}
