import Foundation
import CoreBluetooth
import Combine

enum BleState {
    case unknown, resetting, unsupported, unauthorized, poweredOff, poweredOn
}

protocol BleCentral {
    var status: AnyPublisher<BleState, Never> { get }
    var discovered: AnyPublisher<BlePeer, Never> { get }

    func register(delegates: [BleCentralDelegate])

    // Starts central if status is powered on. If request is sent before status is on, it will be
    // processed when status in on.
    func requestStart()
    func stop()
}

class BleCentralImpl: NSObject, BleCentral {

    let statusSubject = CurrentValueSubject<BleState, Never>(.poweredOff)
    lazy var status = statusSubject.eraseToAnyPublisher()

    let discoveredSubject = PassthroughSubject<BlePeer, Never>()
    lazy var discovered = discoveredSubject.eraseToAnyPublisher()

    let discoveredPairingSubject = PassthroughSubject<PairingBleId, Never>()
    lazy var discoveredPairing = discoveredPairingSubject.eraseToAnyPublisher()

    private let idService: BleIdService

    private var centralManager: CBCentralManager?

    private var validationCharacteristic: CBCharacteristic?
    private var nearbyTokenCharacteristic: CBCharacteristic?
    private var colocatedPairingCharacteristic: CBCharacteristic?

//    private let startTrigger = PassthroughSubject<(), Never>()
    private var startCancellable: AnyCancellable?

    private var discoveredByUuid: [UUID: BleId] = [:]

    private var restoredPeripherals: [CBPeripheral] = []

    private var delegates: [BleCentralDelegate] = []

    private let createCentralSubject = PassthroughSubject<(), Never>()
    private var createCentralCancellable: AnyCancellable?

    // development
    private var verboseLogThrottler = 0

    // If we don't hold a strong reference to the peripheral, Core Bluetooth shows a warning/error: API MISUSE: Cancelling connection for unused peripheral
    // https://stackoverflow.com/questions/34837148/error-corebluetooth-api-misuse-cancelling-connection-for-unused-peripheral
    // It's weird, because we hold a strong reference to it in the delegates?
    // but this made it go away
    // TODO investigate
    private var peripheralReferenceToPreventWarning: CBPeripheral?

    init(idService: BleIdService) {
        self.idService = idService
        super.init()

        startCancellable = status.sink { [weak self] state in
            if state == .poweredOn {
                self?.startScanning()
            }
        }

        createCentralCancellable = createCentralSubject
            .withLatestFrom(status)
            .sink { [weak self] state in
            if state != .poweredOn {
                self?.centralManager = CBCentralManager(delegate: self, queue: nil, options: [
                    CBCentralManagerOptionRestoreIdentifierKey: appDomain,
                    CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true)
                ])
            }
        }
    }

    // Note: has to be called before requestStart()
    func register(delegates: [BleCentralDelegate]) {
        self.delegates = delegates
    }

    func requestStart() {
        log.v("Central requestStart()", .ble)
        // On start we create the central, since this is what triggers enable ble dialog if it's disabled.
        // we also could create a temporary CBPeripheralManager to trigger this and create ours during init
        // but then IIRC we don't get poweredOn delegate call TODO revisit/confirm
        // Actually TODO: using the same mechanism for central and peripheral may be what opens shortly 2 permission dialogs?
        // was this different when initializing them at start? if not, there doesn't seem to be anything we can do
        // as both have to be initialized (simulataneouly). Maybe check stack overflow.
        createCentralSubject.send(())
    }

    func stop() {
        guard let centralManager = centralManager else {
            log.w("Stop central: there's no central set. Exit.", .ble)
            return
        }

        if centralManager.isScanning {
            log.d("Stopping central (was scanning)", .ble)
            centralManager.stopScan()
        }

        discoveredByUuid = [:]
    }

    private func startScanning() {
        guard let centralManager = centralManager else {
            log.e("Start scanning: there's no central set. Exit.", .ble)
            return
        }

        if !centralManager.isScanning {
            log.i("Starting central to scan for peripherals", .ble)
            centralManager.scanForPeripherals(withServices: [.serviceCBUUID], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(booleanLiteral: true)
            ])
        } else {
            log.i("Starting central: central is already scanning. Doing nothing", .ble)
        }
    }

    private func resetPeripheral(_ peripheral: CBPeripheral) {
        log.d("Resetting periperal. State: \(peripheral.state)", .ble)
        if peripheral.state == .connecting || peripheral.state == .connected {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        peripheral.delegate = nil
        discoverServices(peripheral)
    }

    private func discoverServices(_ peripheral: CBPeripheral) {
        log.d("Central discovering services for peripheral: \(peripheral.identifier)", .ble)
        peripheral.discoverServices([CBUUID.serviceCBUUID])
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
        log.d("Cancelling restored peripherals connection \(restoredPeripherals.count)", .ble)

        restoredPeripherals.forEach({
            central.cancelPeripheralConnection($0)
        })
        restoredPeripherals = []
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi: NSNumber) {

        if verboseLogThrottler / 200 == 0 {
            log.v("Discovered peripheral: \(peripheral)", .ble)
            verboseLogThrottler = 0
        }
        verboseLogThrottler = verboseLogThrottler + 1

        guard let centralManager = centralManager else {
            // This probably should be a fatal error, but leaving it in case it happens e.g. when exiting the app.
            // Keep an eye on this on cloud logs.
            log.e("Critical (race condition?): discovered a peripheral but central isn't set. Exit.", .ble)
            return
        }

        peripheral.delegate = self
        delegates.forEach { $0.onDiscoverPeripheral(peripheral, advertisementData: advertisementData, rssi: rssi) }

        peripheralReferenceToPreventWarning = peripheral

        if peripheral.state != .connected && peripheral.state != .connecting {
            // TODO connection count limit?
            log.v("Connecting to peripheral", .ble)
            centralManager.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log.v("Central did connect to peripheral", .ble)
        // Called directly after explicit connection request or on state restoration (app was killed by system)
        // (given that when the app was killed, there was a pending connection request)
        // note on restoring case: the app is relaunched in the background only to handle this request
        discoverServices(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Note: this can be _any_ peripheral (gadgets etc.) not sure a retry here is meaningful
        // if it happens to be our peer, it is, but there's no way to know here.
        // TODO research: when is this called? does ble maybe do some sort of retry? should we do it?
        log.w("Central did fail to connect to peripheral: \(String(describing: error))", .ble)
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

        if services.isEmpty {
            log.e("Error? Peripheral: \(peripheral.identifier) has no services.", .ble)
        }

        for service in services {
            log.v("Central did discover service: \(service)", .ble)
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

        log.d("Central did discover characteristics: \(characteristics.count)", .ble)

        if !delegates.evaluate({ $0.onDiscoverCaracteristics(characteristics, peripheral: peripheral, error: error)}) {
            log.e("One or more characteristics were not handled", .ble)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        delegates.forEach { _ = $0.onReadCharacteristic(characteristic, peripheral: peripheral, error: error) }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        delegates.forEach { _ = $0.onWriteCharacteristicAck(characteristic, peripheral: peripheral, error: error) }
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        log.w("Peripheral invalidated services: \(invalidatedServices). Resetting...", .ble)
        // This was a bit weird: one of the devices didn't seem to have the peripheral activated
        // (no .poweredOn (the peripheral is even manually stopped at the beginning), also after app re-install)
        // the other would still discover it, but without any services. Unclear why this happens.
        // this could be consistently reproduced (create remote session, join, ack on both devices)
        // Anyway: the (solvable) problem is that when we actually start advertising in the former device,
        // the second device still sees no services.
        // Turns that this method is called, telling us that the peripheral's "no services state" was invalidated
        // (since the peripheral started advertising)
        // We've to manually trigger a discovery again (we do this in resetPeripheral) to get the updated services.
        resetPeripheral(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Trigger a connection request if peripheral goes out of range to re-connect automatically when it's in range again.
        // (connection requests don't time out.)
        // https://apple.co/3l09b1i
        log.d("Peripheral disconnected. Requesting connection again.", .ble)
        central.connect(peripheral, options: [:])
    }
}

class BleCentralNoop: NSObject, BleCentral {
    let status: AnyPublisher<BleState, Never> = Just(.poweredOn).eraseToAnyPublisher()
    let discovered = PassthroughSubject<BlePeer, Never>().eraseToAnyPublisher()
    let discoveredPairing = PassthroughSubject<PairingBleId, Never>().eraseToAnyPublisher()
    let statusMsg = PassthroughSubject<String, Never>()
    func requestStart() {}
    func register(delegates: [BleCentralDelegate]) {}
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
    func register(delegates: [BleCentralDelegate]) {}
    func stop() {}
    func write(nearbyToken: SerializedSignedNearbyToken) -> Bool { true }
    func write(publicKey: SerializedEncryptedPublicKey) -> Bool { true }
    func validatePeer() -> Bool { true }
}
