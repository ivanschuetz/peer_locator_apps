import Foundation
import CoreBluetooth
import Combine

enum BleState {
    case unknown, resetting, unsupported, unauthorized, poweredOff, poweredOn
}

protocol BleCentral {
    var status: AnyPublisher<BleState, Never> { get }
    var discovered: AnyPublisher<BlePeer, Never> { get }

    // Starts central if status is powered on. If request is sent before status is on, it will be
    // processed when status in on.
    func requestStart()
    func stop()
}

class BleCentralImpl: NSObject, BleCentral {

    let statusSubject = PassthroughSubject<BleState, Never>()
    lazy var status = statusSubject.eraseToAnyPublisher()

    let discoveredSubject = PassthroughSubject<BlePeer, Never>()
    lazy var discovered = discoveredSubject.eraseToAnyPublisher()

    let discoveredPairingSubject = PassthroughSubject<PairingBleId, Never>()
    lazy var discoveredPairing = discoveredPairingSubject.eraseToAnyPublisher()

    private let idService: BleIdService

    private var centralManager: CBCentralManager!

    private var validationCharacteristic: CBCharacteristic?
    private var nearbyTokenCharacteristic: CBCharacteristic?
    private var colocatedPairingCharacteristic: CBCharacteristic?

    private let startTrigger = PassthroughSubject<(), Never>()
    private var startCancellable: AnyCancellable?

    private var discoveredByUuid: [UUID: BleId] = [:]

    private var restoredPeripherals: [CBPeripheral] = []

    private var delegates: [BleCentralDelegate] = []

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

        peripheral.delegate = self
        delegates.forEach { $0.onDiscoverPeripheral(peripheral, advertisementData: advertisementData, rssi: rssi) }

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

        // TODO error handling: probably in the delegates

        if !delegates.allSatisfy({ $0.onDiscoverCaracteristics(characteristics, peripheral: peripheral, error: error)}) {
            log.e("One or more characteristics were not handled", .ble)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        delegates.forEach { _ = $0.onReadCharacteristic(characteristic, peripheral: peripheral, error: error) }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        log.d("didWriteValueFor: \(characteristic), error?: \(String(describing: error))")
        // TODO is this the write ack? error handling? retry?
    }
}

class BleCentralNoop: NSObject, BleCentral {
    let status: AnyPublisher<BleState, Never> = Just(.poweredOn).eraseToAnyPublisher()
    let discovered = PassthroughSubject<BlePeer, Never>().eraseToAnyPublisher()
    let discoveredPairing = PassthroughSubject<PairingBleId, Never>().eraseToAnyPublisher()
    let statusMsg = PassthroughSubject<String, Never>()
    func requestStart() {}
    func stop() {}
    func write(nearbyToken: SerializedSignedNearbyToken) -> Bool { true }
    func write(publicKey: SerializedEncryptedPublicKey) -> Bool { true }
    func validatePeer() -> Bool { true }
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
    let discovered = Just(BlePeer(deviceUuid: UUID(), id: BleId(str: "123")!, distance: 10.2)).eraseToAnyPublisher()
    var discoveredPairing = Just(PairingBleId(str: "123")!).eraseToAnyPublisher()
    let status = Just(BleState.poweredOn).eraseToAnyPublisher()
    func requestStart() {}
    func stop() {}
    func write(nearbyToken: SerializedSignedNearbyToken) -> Bool { true }
    func write(publicKey: SerializedEncryptedPublicKey) -> Bool { true }
    func validatePeer() -> Bool { true }
}
