import CoreBluetooth
import Combine

// TODO more splitting? this is doing validation and distance

class BleMeetingValidation {
    let discoveredSubject = PassthroughSubject<BleParticipant, Never>()
    lazy var discovered = discoveredSubject.eraseToAnyPublisher()

    private let characteristicUuid = CBUUID(string: "0be778a3-2096-46c8-82c9-3a9d63376512")

    private let idService: BleIdService

    private var peripheral: CBPeripheral?

    private var discoveredByUuid: [UUID: BleId] = [:]

    private var discoveredCharacteristic: CBCharacteristic?

    init(idService: BleIdService) {
        self.idService = idService
    }

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

        if let id = discoveredByUuid[peripheral.identifier] {
            let powerLevelMaybe = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
            let estimatedDistanceMeters = estimateDistance(
                rssi: rssi.doubleValue,
                powerLevelMaybe: powerLevelMaybe
            )
            log.d("Distance: \(estimatedDistanceMeters)", .ble)
            discoveredSubject.send(BleParticipant(id: id, distance: estimatedDistanceMeters))
        }
    }

    func onDiscoverCaracteristics(_ characteristics: [CBCharacteristic], peripheral: CBPeripheral, error: Error?) -> Bool {
        if let characteristic = characteristics.first(where: {
            $0.uuid == characteristicUuid
        }) {
            log.d("Reading the validation characteristic", .ble)
            self.discoveredCharacteristic = characteristic
            // temporarily disabled as it causes noise when ble is always on
            // on RSSI measurements we continuously trigger validation
            // TODO tackle. should it stay disabled?
            // TODO if we want to trigger read from app, instead of here,
            // we need an observable with "(validation)characteristic ready"
            peripheral.readValue(for: characteristic)
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
                log.d("Received id: \(id), device uuid: \(peripheral.identifier)", .ble)
                discoveredByUuid[peripheral.identifier] = id
                discoveredSubject.send(BleParticipant(id: id, distance: -1)) // TODO distance
            } else {
                log.w("Verification characteristic had no value", .ble)
            }
            return true
        default: return false
        }
    }
}

func estimateDistance(rssi: Double, powerLevelMaybe: Int?) -> Double {
    log.d("Estimating distance for rssi: \(rssi), power level: \(String(describing: powerLevelMaybe))")
    return estimatedDistance(
        rssi: rssi,
        powerLevel: powerLevel(powerLevelMaybe: powerLevelMaybe)
    )
}

func powerLevel(powerLevelMaybe: Int?) -> Double {
    // It seems we have to hardcode this, at least for Android
    // TODO do we have to differentiate between device brands? maybe we need a "handshake" where device
    // communicates it's power level via custom advertisement or gatt?
    return powerLevelMaybe.map { Double($0) } ?? -80 // measured with Android (pixel 3)
}

// The power level is the RSSI at one meter. RSSI is negative, so we make it negative too
// the results seem also not correct, so adjusted
func powerLevelToUse(_ powerLevel: Double) -> Double {
    switch powerLevel {
        case 12...20:
            return -58
        case 9..<12:
            return -72
        default:
            return -87
    }
}

func estimatedDistance(rssi: Double, powerLevel: Double) -> Double {
    guard rssi != 0 else {
        return -1
    }
    let pw = powerLevelToUse(powerLevel)
    return pow(10, (pw - rssi) / 20)  // TODO environment factor
}
