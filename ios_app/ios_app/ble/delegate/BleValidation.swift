import CoreBluetooth
import Combine

/**
 * Sends and receives ble peer validation data
 */
protocol BleValidation: BlePeripheralDelegate, BleCentralDelegate {
    var read: AnyPublisher<BlePeer, Never> { get }
    var errorReadingValidation: AnyPublisher<Error, Never> { get }

    /*
     * @returns whether validation request was sent.
     */
    func validatePeer() -> Bool
}

class BleValidationImpl: BleValidation {
    let readSubject = PassthroughSubject<BlePeer, Never>()
    lazy var read = readSubject.eraseToAnyPublisher()

    private let errorReadingValidationSubject = PassthroughSubject<Error, Never>()
    lazy var errorReadingValidation = errorReadingValidationSubject.compactMap{ $0 }.eraseToAnyPublisher()

    private let characteristicUuid = CBUUID(string: "0be778a3-2096-46c8-82c9-3a9d63376512")

    private let idService: BleIdService

    private var peripheral: CBPeripheral?

    private var discoveredCharacteristic: CBCharacteristic?

    private var retry: RetryData<()>?

    var cancellables: Set<AnyCancellable> = []

    init(idService: BleIdService) {
        self.idService = idService
    }

    // TODO(pmvp) check if/when peer device uuid can change and if yes, how our validation/timer behaves.
    // TODO(pmvp) and test colocated to meeting transition, with separation in between
    // (including e.g. toggling bluetooth)
    func validatePeer() -> Bool {
        guard let peripheral = peripheral else {
            log.e("Attempted to validate peer, but peripheral is not set.", .ble)
            return false
        }
        guard let characteristic = discoveredCharacteristic else {
            log.e("Attempted to validate peer, but characteristic is not set.", .ble)
            return false
        }
        log.d("Sending validation data read request", .ble)
        peripheral.readValue(for: characteristic)
        return true
    }
}

extension BleValidationImpl: BlePeripheralDelegateReadOnly {
    var characteristic: CBMutableCharacteristic {
        CBMutableCharacteristic(
            type: characteristicUuid,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
    }

    func handleRead(uuid: CBUUID, request: CBATTRequest, peripheral: CBPeripheralManager) {
        log.v("Peripheral received validation read request", .ble)
        if let myId = idService.id() {
            request.value = myId.data
            log.d("Peripheral sending validation data", .ble)
            peripheral.respond(to: request, withResult: .success)

        } else {
            // TODO(pmvp) review handling
            // This state is valid as peripheral and central are active during colocated pairing too,
            // where normally there's no session yet
            // TODO(pmvp) probably we should block reading session data during colocated pairing / non-active session
            log.v("Peripheral session id was read and there was no session (see comment)")
        }
    }
}

extension BleValidationImpl: BleCentralDelegate {

    func onConnectPeripheral(_ peripheral: CBPeripheral) {
        log.d("Ble validation connected with peripheral: \(peripheral)", .ble)
        self.peripheral = peripheral
    }

    func onDidFailToConnectToPeripheral(_ peripheral: CBPeripheral) {}

    func onDisconnectPeripheral(_ peripheral: CBPeripheral) {
        self.peripheral = nil
    }

    func onDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {}

    func onDiscoverCaracteristics(_ characteristics: [CBCharacteristic], peripheral: CBPeripheral, error: Error?) -> Bool {
        log.d("Ble validation discovered peripheral's characteristics (\(characteristics.count))", .ble)

        if let characteristic = characteristics.first(where: {
            $0.uuid == characteristicUuid
        }) {
            log.d("Reading the validation characteristic", .ble)
            self.discoveredCharacteristic = characteristic
            if !validatePeer() {
                log.e("Likely invalid state: sending validation request here should always work", .ble)
            }
            return true
        } else {
            log.e("Service doesn't have validation characteristic.", .ble)
            return false
        }
    }

    func onReadCharacteristic(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) -> Bool {
        switch characteristic.uuid {
        case characteristicUuid:
            log.d("Central received validation data. Is error?: \(error != nil)", .ble)
            if let error = error {
                handleReadError(error)
            } else {
                if let value = characteristic.value {
                    guard let id = BleId(data: value) else {
                        log.e("Unexpected: Couldn't parse data: \(value) to ble id", .ble)
                        return false
                    }
                    log.d("Central forwarding validation data", .ble)
                    // TODO(next) use new struct (not BlePeer). We don't have distance here.
                    readSubject.send(BlePeer(deviceUuid: peripheral.identifier, id: id, distance: -1))
                } else {
                    let msg = "Verification characteristic had no value"
                    log.e(msg, .ble)
                    handleReadError(ServicesError.general(msg))
                }
            }
            return true
        default: return false
        }
    }

    private func handleReadError(_ error: Error) {
        log.e("Error reading validation characteristic: \(error)", .ble)
        
        if let retry = retry {
            if retry.shouldRetry() {
                log.d("Retrying colocated key write. Attempt: \(retry.count)", .ble)
                self.retry = retry.increment()
                _ = validatePeer()
            } else {
                log.d("Failed colocated key write after \(retry.count) attempts. Error.", .ble)
                errorReadingValidationSubject.send(error)
            }
        } else {
            log.e("Illegal state? retry should be set when receiving ack", .ble)
            errorReadingValidationSubject.send(error)
        }
    }

    func onWriteCharacteristicAck(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) {
        if characteristic.uuid == characteristicUuid {
            fatalError("We don't write validation characteristic")
        }
    }
}
