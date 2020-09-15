import CoreBluetooth
import Combine

class BleMeetingValidation {
    let discoveredSubject = PassthroughSubject<BlePeer, Never>()
    lazy var discovered = discoveredSubject.eraseToAnyPublisher()

    private let characteristicUuid = CBUUID(string: "0be778a3-2096-46c8-82c9-3a9d63376512")

    private let idService: BleIdService

    private var peripheral: CBPeripheral?

    private var discoveredCharacteristic: CBCharacteristic?

    init(idService: BleIdService) {
        self.idService = idService
    }

    // Currently this is called only upon discovering characteristic
    // TODO we need to trigger validation again (probably using timer)
    // if user is validated during colocated pairing, we remember uuid as valid
    // what if uuid changes before the actual meeting? ok, we will detect a new peripheral/uuid and validate that one
    // so we've 2 valid uuids stored -> the user will be validated.
    // but anyway, this is not ideal security. We should re-validate each x seconds to prevent replay attacks.
    // this is not needed pre-mvp though.
    // TODO at least test that things work (user is validated) if uuid changes.
    // and test in general colocated to meeting transition, with separation in between
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
        log.d("Validing peer", .ble)
        peripheral.readValue(for: characteristic)
        return true
    }
}

extension BleMeetingValidation: BlePeripheralDelegateReadOnly {
    var characteristic: CBMutableCharacteristic {
        CBMutableCharacteristic(
            type: characteristicUuid,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
    }

    func handleRead(uuid: CBUUID, request: CBATTRequest, peripheral: CBPeripheralManager) {
        if let myId = idService.id() {
//            self.readMyId.send(myId)
            request.value = myId.data
            peripheral.respond(to: request, withResult: .success)

        } else {
            // TODO review handling
            // This state is valid as peripheral and central are active during colocated pairing too,
            // where normally there's no session yet
            // TODO probably we should block reading session data during colocated pairing / non-active session
            log.v("Peripheral session id was read and there was no session (TODO see comment)")
        }
    }
}

extension BleMeetingValidation: BleCentralDelegate {

    func onDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        self.peripheral = peripheral
    }

    func onDiscoverCaracteristics(_ characteristics: [CBCharacteristic], peripheral: CBPeripheral, error: Error?) -> Bool {
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
            if let value = characteristic.value {
                // Unwrap: We send BleId, so we always expect BleId
                let id = BleId(data: value)!
                discoveredSubject.send(BlePeer(deviceUuid: peripheral.identifier, id: id,
                                               distance: -1)) // TODO distance: handle this?
            } else {
                log.w("Verification characteristic had no value", .ble)
            }
            return true
        default: return false
        }
    }
}
