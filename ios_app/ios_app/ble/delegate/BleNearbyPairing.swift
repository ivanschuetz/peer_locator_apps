import CoreBluetooth
import Combine

// TODO we have to use validated peripheral everywhere, as we of course can detect more than one peripheral
// (everyone using the app)
// --> ensure that we're reading and writing to our peer's peripheral
// TODO confirm too that we can detect only one validated peripheral at a time.
// Note that during normal operation, we will be reading from _all_ nearby users of the app, until a validation
// succeeds (we find our peer) -> TODO ensure this doesn't cause problems (validation is expensive: how many devices
// max can we support? we should expose the session id in clear text and validate only if session id matches.
// note that this allows observers to detect who belongs together. TODO clarify about using variable characteristic and service uuid
// if this is possible we can use this instead of session id,
// it would be a bit more difficult to track for others as they can't use the service uuid to identify our app.
// so a given pair would have the same service/char uuid but this could be _any_ service, so it _should_ (?) be more
// difficult to track.
// keep in mind nonce also: if we don't encrypt, where would it be? if we encrypt, what's there to encrypt if
// the session id has to be plain text? should we add a (clear text) random number nonce to the clear text (session id)?


/*
 * Writes the Nearby discovery token to peer.
 * If both devices support Nearby, a session will be created, by each writing its discovery token to the peer.
 * If a device doesn't support Nearby, it just does nothing (don't write the token)
 * This way a session isn't established, so there's no nearby measurements and we stay with ble.
 */
protocol NearbyPairing: BlePeripheralDelegate, BleCentralDelegate {
    var token: AnyPublisher<SerializedSignedNearbyToken, Never> { get }

    // For now not used, as we've a timer to send the nearby token each x secs until it succeeds.
    // and sending the discovery token is triggered by coming in range, not user interaction
    // so it probably doesn't make sense to show an error or retry dialog.
    // Worst case: keeps retrying "forever", connection uses only ble. Errors are sent to cloud logging.
    var errorSendingToken: AnyPublisher<Error, Never> { get }
    
    func sendDiscoveryToken(token: SerializedSignedNearbyToken)
}

class BleNearbyPairing: NearbyPairing {
    private let tokenSubject = CurrentValueSubject<SerializedSignedNearbyToken?, Never>(nil)
    lazy var token = tokenSubject.compactMap{ $0 }.eraseToAnyPublisher()

    private let errorSendingTokenSubject = PassthroughSubject<Error, Never>()
    lazy var errorSendingToken = errorSendingTokenSubject.compactMap{ $0 }.eraseToAnyPublisher()

    private let characteristicUuid = CBUUID(string: "0be778a3-2096-46c8-82c9-3a9d63376513")

    private let validatedPeripheral: AnyPublisher<CBPeripheral?, Never>

    private var discoveredCharacteristic = CurrentValueSubject<CBCharacteristic?, Never>(nil)

    private let connectedPeripherals = PassthroughSubject<CBPeripheral, Never>()
    private let writeToken = PassthroughSubject<SerializedSignedNearbyToken, Never>()

    private var writeTokenCancellable: AnyCancellable?

    private var retry: RetryData<SerializedSignedNearbyToken>?

    init(bleValidator: BleDeviceValidatorService) {
        validatedPeripheral = connectedPeripherals
            // Collect all the connected peripherals (i.e. peripherals exposing our service/characteristic)
            // to filter valid one
            .scan([UUID: CBPeripheral](), { dict, peripheral in
                var mutDict = dict
                mutDict[peripheral.identifier] = peripheral
                return mutDict
            })
            .combineLatest(bleValidator.validDevices) { peripherals, validDevices in
                (peripherals, validDevices)
            }
            .compactMap { peripherals, validDevices -> CBPeripheral? in
                filterValidPeripheral(connectedPeripherals: peripherals, validDeviceUuids: Array(validDevices.keys))
            }
            .eraseToAnyPublisher()

        writeTokenCancellable = writeToken
            // It's not an issue if peripheral is not available yet. Write nearby token is triggered periodically.
            .withLatestFrom(validatedPeripheral) { token, peripheral in (token, peripheral) }
            .withLatestFrom(discoveredCharacteristic) { tuple, characteristic in
                (tuple.0, tuple.1, characteristic) }
            .sink { [weak self] token, peripheral, characteristic in
                self?.doSendDiscoveryToken(token: token, peripheral: peripheral, characteristic: characteristic)
            }
    }

    func sendDiscoveryToken(token: SerializedSignedNearbyToken) {
        retry = RetryData(token)
        writeToken.send(token)
    }

    func doSendDiscoveryToken(token: SerializedSignedNearbyToken, peripheral: CBPeripheral?,
                              characteristic: CBCharacteristic?) {
        guard let peripheral = peripheral else {
            log.e("Attempted to write, but peripheral is not set.", .ble)
            return
        }
        guard let characteristic = characteristic else {
            log.e("Attempted to write, but nearby characteristic is not set.", .ble)
            return
        }
        peripheral.writeValue(token.data, for: characteristic, type: .withResponse)
    }
}

private func filterValidPeripheral(connectedPeripherals: [UUID: CBPeripheral], validDeviceUuids: [UUID]) -> CBPeripheral? {
    log.v("Validating peripherals: \(connectedPeripherals.keys)", .nearby)
    for validDeviceUuid in validDeviceUuids {
        if let peripheral = connectedPeripherals[validDeviceUuid] {
            log.v("One of the connected peripherals is valid: \(peripheral.identifier)", .nearby)
            return peripheral
        }
    }
    log.v("None of the connected peripherals \(connectedPeripherals) are valid", .nearby)
    return nil
}

extension BleNearbyPairing: BlePeripheralDelegateWriteOnly {

    var characteristic: CBMutableCharacteristic {
        CBMutableCharacteristic(
            type: characteristicUuid,
            properties: [.write],
            value: nil,
            // Note that we don't use encryption (.writeEncryptionRequired / .readEncryptionRequired)
            // (also in all the other characteristics)
            // as our goal is to connect unknown (not trusted) devices
            permissions: [.writeable]
        )
    }

    func handleWrite(data: Data) {
        tokenSubject.send(SerializedSignedNearbyToken(data: data))
    }
}

extension BleNearbyPairing: BleCentralDelegate {

    func onConnectPeripheral(_ peripheral: CBPeripheral) {
        connectedPeripherals.send(peripheral)
    }

    func onDidFailToConnectToPeripheral(_ peripheral: CBPeripheral) {}

    func onDisconnectPeripheral(_ peripheral: CBPeripheral) {
        // Our peripheral is a passthrough subject. Nothing to clear here.
    }

    func onDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {}

    func onDiscoverCaracteristics(_ characteristics: [CBCharacteristic], peripheral: CBPeripheral,
                                  error: Error?) -> Bool {
        if let discoveredCharacteristic = characteristics.first(where: {
            $0.uuid == characteristicUuid
        }) {
            log.d("Setting the nearby characteristic", .ble)
            self.discoveredCharacteristic.send(discoveredCharacteristic)
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
        log.e("Error: \(error) writing nearby token: \(characteristic)", .ble)
        if let retry = retry {
            if retry.shouldRetry() {
                log.d("Retrying nearby token write. Attempt: \(retry.count)", .ble)
                self.retry = retry.increment()
                sendDiscoveryToken(token: retry.data)
            } else {
                log.d("Failed nearby token write after \(retry.count) attempts. Error.", .ble)
                errorSendingTokenSubject.send(error)
            }
        } else {
            log.e("Illegal state? retry should be set when receiving ack", .ble)
            errorSendingTokenSubject.send(error)
        }
    }
}
