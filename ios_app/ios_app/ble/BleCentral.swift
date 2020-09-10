import Foundation
import CoreBluetooth
import Combine

enum BleState {
    case unknown, resetting, unsupported, unauthorized, poweredOff, poweredOn
}

protocol BleCentral {
    var status: AnyPublisher<BleState, Never> { get }
    var writtenMyId: PassthroughSubject<BleId, Never> { get }
    var discovered: AnyPublisher<BleParticipant, Never> { get }
    var discoveredPairing: AnyPublisher<PairingBleId, Never> { get }

    // Starts central if status is powered on. If request is sent before status is on, it will be
    // processed when status in on.
    func requestStart()
    func stop()

    func validatePeer() -> Bool
    func write(nearbyToken: SerializedSignedNearbyToken) -> Bool
    func write(publicKey: SerializedEncryptedPublicKey) -> Bool
}

class BleCentralImpl: NSObject, BleCentral {

    let statusSubject = PassthroughSubject<BleState, Never>()
    lazy var status = statusSubject.eraseToAnyPublisher()

    let writtenMyId = PassthroughSubject<BleId, Never>()

    let discoveredSubject = PassthroughSubject<BleParticipant, Never>()
    lazy var discovered = discoveredSubject.eraseToAnyPublisher()

    let discoveredPairingSubject = PassthroughSubject<PairingBleId, Never>()
    lazy var discoveredPairing = discoveredPairingSubject.eraseToAnyPublisher()

    private let idService: BleIdService

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?

    private var validationCharacteristic: CBCharacteristic?
    private var nearbyTokenCharacteristic: CBCharacteristic?
    private var colocatedPairingCharacteristic: CBCharacteristic?

    private let startTrigger = PassthroughSubject<(), Never>()
    private var startCancellable: AnyCancellable?

    private var discoveredByUuid: [UUID: BleId] = [:]

    private var restoredPeripherals: [CBPeripheral] = []

    init(idService: BleIdService) {
        self.idService = idService
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionRestoreIdentifierKey: appDomain,
            CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true)
        ])

        startCancellable = startTrigger
            .combineLatest(status)
            .map { _, status in status }
            .removeDuplicates()
            .sink(receiveValue: {[weak self] status in
                if status == .poweredOn {
                    self?.start()
                } else {
                    log.d("Requested central start while not powered on: \(status)", .ble)
                }
            })
    }

    func requestStart() {
        startTrigger.send(())
    }

    func stop() {
        if centralManager?.isScanning ?? false {
            log.d("Stopping central (was scanning)", .ble)
            centralManager?.stopScan()
        }
        discoveredByUuid = [:]
    }

    private func start() {
        log.i("Will start central", .ble)
        centralManager.scanForPeripherals(withServices: [.serviceCBUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(booleanLiteral: true)
        ])
    }

    private func flush(_ peripheral: CBPeripheral) {}

    func write(nearbyToken: SerializedSignedNearbyToken) -> Bool {
        guard let peripheral = peripheral else {
            log.e("Attempted to write, but peripheral is not set.", .ble)
            return false
        }
        guard let nearbyTokenCharacteristic = nearbyTokenCharacteristic else {
            log.e("Attempted to write, but nearby characteristic is not set.", .ble)
            return false
        }
        peripheral.writeValue(nearbyToken.data, for: nearbyTokenCharacteristic, type: .withResponse)
        return true
    }

    // TODO confirm: is the peripheral reliable available here? Probably we should use reactive
    // instead, with poweredOn + write?
    func write(publicKey: SerializedEncryptedPublicKey) -> Bool {
        guard let peripheral = peripheral else {
            log.e("Attempted to write, but peripheral is not set.", .ble)
            return false
        }
        guard let colocatedPairingCharacteristic = colocatedPairingCharacteristic else {
            log.e("Attempted to write, but colocated public key characteristic is not set.", .ble)
            return false
        }
        log.d("Writing public key to colocated characteristic", .ble)
        peripheral.writeValue(publicKey.data, for: colocatedPairingCharacteristic, type: .withResponse)
        return true
    }

    func validatePeer() -> Bool {
        guard let peripheral = peripheral else {
            log.e("Attempted to validate peer, but peripheral is not set.", .ble)
            return false
        }
        guard let validationCharacteristic = validationCharacteristic else {
            log.e("Attempted to validate peer, but colocated public key characteristic is not set.", .ble)
            return false
        }
        log.d("Validing peer", .ble)
        peripheral.readValue(for: validationCharacteristic)
        return true
    }
}

extension BleCentralImpl: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state.toBleState()
        log.d("Central ble state: \(state)", .ble)
        statusSubject.send(state)

        if central.state == .poweredOn {
            cancelRestoredPeripherals(central: central)
        }
    }

    private func cancelRestoredPeripherals(central: CBCentralManager) {
        restoredPeripherals.forEach({
            central.cancelPeripheralConnection($0)
        })
        restoredPeripherals = []
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi: NSNumber) {
//        log.v("Discovered peripheral: \(peripheral)", .ble)

        self.peripheral = peripheral
        peripheral.delegate = self

        if let id = discoveredByUuid[peripheral.identifier] {
            let powerLevelMaybe = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
            let estimatedDistanceMeters = estimateDistance(
                rssi: rssi.doubleValue,
                powerLevelMaybe: powerLevelMaybe
            )
            log.d("Distance: \(estimatedDistanceMeters)", .ble)
            discoveredSubject.send(BleParticipant(id: id, distance: estimatedDistanceMeters))
        }

        if peripheral.state != .connected && peripheral.state != .connecting {
            // TODO connection count limit?
            log.v("Connecting to peripheral", .ble)
            centralManager.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log.v("Did connect to peripheral", .ble)
        peripheral.discoverServices([CBUUID.serviceCBUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log.v("Did fail to connect to peripheral", .ble)
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        log.d("Central will restore state: \(dict)", .ble, .bg)
        // Remember restored peripherals to cancel the connections when the central is powered on
        // TODO review: do we really need this?
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            log.d("Restored peripherals: \(peripherals)", .ble, .bg)
            self.restoredPeripherals = peripherals
        }
    }
}

extension BleCentralImpl: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            log.e("Error discovering services: \(error)", .ble)
        }

        guard let services = peripheral.services else { return }
        for service in services {
            log.v("Did discover service: \(service)", .ble)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
//        // Debugging
//        guard let characteristics = service.characteristics else { return }
//        for characteristic in characteristics {
//            log.v("Did read  characteristic: \(characteristic)", .ble)
//            if characteristic.properties.contains(.read) {
//                log.v("\(characteristic.uuid): properties contains .read", .ble)
//            }
//        }

        // TODO since we will not use the advertisement data (TODO confirm), both devices can use read requests
        // no need to do write (other that for possible ACKs later)

        guard let characteristics = service.characteristics else {
            log.e("Should not happen? service has no characteristics", .ble)
            return
        }

        log.d("Did discover characteristics: \(characteristics.count)", .ble)

        if let validationCharacteristic = characteristics.first(where: {
            $0.uuid == .characteristicCBUUID
        }) {
            log.d("Reading the validation characteristic", .ble)
            self.validationCharacteristic = validationCharacteristic
            // temporarily disabled as it causes noise when ble is always on
            // on RSSI measurements we continuously trigger validation
            // TODO tackle. should it stay disabled?
//            peripheral.readValue(for: validationCharacteristic)
        } else {
            log.e("Service doesn't have validation characteristic.", .ble)
        }

        if let nearbyTokenCharacteristic = characteristics.first(where: {
            $0.uuid == .nearbyCharacteristicCBUUID
        }) {
            log.d("Setting the nearby characteristic", .ble)
            self.nearbyTokenCharacteristic = nearbyTokenCharacteristic
        } else {
            log.e("Service doesn't have nearby characteristic.", .ble)
        }

        if let colocatedPairingCharacteristic = characteristics.first(where: {
            $0.uuid == .colocatedPublicKeyCBUUID
        }) {
            log.d("Setting the colocated pairing characteristic", .ble)
            self.colocatedPairingCharacteristic = colocatedPairingCharacteristic
        } else {
            log.e("Service doesn't have public key pairing characteristic.", .ble)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case CBUUID.characteristicCBUUID:
            if let value = characteristic.value {
                // Unwrap: We send BleId, so we always expect BleId
                let id = BleId(data: value)!
                log.d("Received id: \(id), device uuid: \(peripheral.identifier)", .ble)
                discoveredByUuid[peripheral.identifier] = id
                discoveredSubject.send(BleParticipant(id: id, distance: -1)) // TODO distance
            } else {
                log.w("Verification characteristic had no value", .ble)
            }
        case CBUUID.colocatedPublicKeyCBUUID:
            if let value = characteristic.value {
                // Unwrap: We send PairingBleId, so we always expect PairingBleId
                let id = PairingBleId(data: value)!
                log.d("Received id: \(id), device uuid: \(peripheral.identifier)", .ble)
                discoveredPairingSubject.send(id)
            } else {
                log.w("Pairing characteristic had no value", .ble)
            }
          default:
            log.w("Unexpected characteristic UUID: \(characteristic.uuid)", .ble)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        log.d("didWriteValueFor: \(characteristic), error?: \(String(describing: error))")
        // TODO is this the write ack? error handling? retry?
    }
}

class BleCentralNoop: NSObject, BleCentral {
    let status: AnyPublisher<BleState, Never> = Just(.poweredOn).eraseToAnyPublisher()
    let discovered = PassthroughSubject<BleParticipant, Never>().eraseToAnyPublisher()
    let discoveredPairing = PassthroughSubject<PairingBleId, Never>().eraseToAnyPublisher()
    let statusMsg = PassthroughSubject<String, Never>()
    let writtenMyId = PassthroughSubject<BleId, Never>()
    func requestStart() {}
    func stop() {}
    func write(nearbyToken: SerializedSignedNearbyToken) -> Bool { true }
    func write(publicKey: SerializedEncryptedPublicKey) -> Bool { true }
    func validatePeer() -> Bool { true }
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

extension CBManagerState {
    func toBleState() -> BleState {
        switch self {
        case .poweredOff: return .poweredOff
        case .poweredOn: return .poweredOn
        case .resetting: return .resetting
        case .unauthorized: return .unauthorized
        case .unknown: return .unknown
        case .unsupported: return .unsupported
        @unknown default:
            log.w("Unhandled new CB state: \(self). Defaulting to .unknown", .ble)
            return .unknown
        }
    }
}

class BleCentralFixedDistance: NSObject, BleCentral {
    let discovered = Just(BleParticipant(id: BleId(str: "123")!,
                                         distance: 10.2)).eraseToAnyPublisher()
    var discoveredPairing = Just(PairingBleId(str: "123")!).eraseToAnyPublisher()
    let status = Just(BleState.poweredOn).eraseToAnyPublisher()
    let writtenMyId = PassthroughSubject<BleId, Never>()
    func requestStart() {}
    func stop() {}
    func write(nearbyToken: SerializedSignedNearbyToken) -> Bool { true }
    func write(publicKey: SerializedEncryptedPublicKey) -> Bool { true }
    func validatePeer() -> Bool { true }
}
