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
    private var cancellables: Set<AnyCancellable> = []

    private var discoveredByUuid: [UUID: BleId] = [:]

    private var delegates: [BleCentralDelegate] = []

    // development
    private var verboseLogThrottler = 0

    // If we don't hold a strong reference to the peripheral, Core Bluetooth shows a warning/error: API MISUSE: Cancelling connection for unused peripheral
    // https://stackoverflow.com/questions/34837148/error-corebluetooth-api-misuse-cancelling-connection-for-unused-peripheral
    // It's weird, because we hold a strong reference to it in the delegates?
    // but this made it go away
    // TODO investigate
    private var peripheralReferenceToPreventWarning: CBPeripheral?

    init(idService: BleIdService, appEvents: AppEvents) {
        self.idService = idService
        super.init()

        appEvents.events
            .filter { $0 == .didLaunch }
            .sink { [weak self] _ in
                log.d("Initializing central manager", .blep)
                self?.centralManager = CBCentralManager(delegate: self, queue: nil, options: [
                    CBCentralManagerOptionRestoreIdentifierKey: appDomain,
                    CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true)
                ])
        }
        .store(in: &cancellables)

        status.sink { [weak self] state in
            if state == .poweredOn {
                self?.startScanning()
            }
        }
        .store(in: &cancellables)
    }

    // Note: has to be called before requestStart()
    func register(delegates: [BleCentralDelegate]) {
        self.delegates = delegates
    }

    func stop() {
        guard let centralManager = centralManager else {
            log.w("Stop central: there's no central set. Exit.", .blec)
            return
        }

        if centralManager.isScanning {
            log.d("Stopping central (was scanning)", .blec)
            centralManager.stopScan()
        }

        discoveredByUuid = [:]
    }

    private func startScanning() {
        guard let centralManager = centralManager else {
            log.e("Start scanning: there's no central set. Exit.", .blec)
            return
        }

        if !centralManager.isScanning {
            log.i("Starting central to scan for peripherals", .blec)
            centralManager.scanForPeripherals(withServices: [.serviceCBUUID], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(booleanLiteral: true)
            ])
        } else {
            log.i("Starting central: central is already scanning. Doing nothing", .blec)
        }
    }

    private func resetPeripheral(_ peripheral: CBPeripheral) {
        log.d("Resetting periperal. State: \(peripheral.state)", .blec)
        if peripheral.state == .connecting || peripheral.state == .connected {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        peripheral.delegate = nil
        startDiscovery(peripheral)
    }

    private func startDiscovery(_ peripheral: CBPeripheral) {
        log.d("Central discovering services for peripheral: \(peripheral.identifier)", .blec)

        // Don't discover services/characteristics again if they're cached (restored peripheral)
        // TODO check that the local peripheral here is the same as the restored peripheral
        // (i.e. that it has cached services/characteristics, when applicable)
        // https://apple.co/3l09b1i "Update Your Initialization Process" section

        if let alreadyDiscoveredServices = peripheral.services {
            if let service = alreadyDiscoveredServices.first(where: { $0.uuid == CBUUID.serviceCBUUID }) {

                if let alreadyDiscoveredCharacteristics = service.characteristics {
                    switch alreadyDiscoveredCharacteristics.count {
                    case 3:
                        log.d("Restored peripheral has cached service and characteristics.", .blec, .bg)
                        // It's our service, so we assume that the 3 characteristics are our expected characteristics.
                        onRetrieveCharacteristics(characteristics: alreadyDiscoveredCharacteristics,
                                                  peripheral: peripheral, error: nil)
                    case 0:
                        // TODO check if this is true
                        log.e("Maybe invalid state? If there are no characteristics it should be nil?", .blec, .bg)
                    default:
                        log.e("Invalid restored characteristics count \(alreadyDiscoveredCharacteristics.count): " +
                                "\(alreadyDiscoveredCharacteristics)", .blec, .bg)
                    }
                } else {
                    log.d("Restored peripheral has cached service and no cached characteristics. " +
                          "Triggering characteristics discovery.", .blec, .bg)
                    peripheral.discoverCharacteristics(nil, for: service)
                }

            } else {
                log.e("Invalid state?: Restored peripheral has cached services, but not ours. " +
                    "Triggering a new service discovery", .blec, .bg)
                peripheral.discoverServices([CBUUID.serviceCBUUID])
            }
        } else {
            log.d("Peripheral has no cached service. Triggering service discovery.", .blec, .bg)
            peripheral.discoverServices([CBUUID.serviceCBUUID])
        }
    }

    /**
     * Common entry point for "normal" discovery and retrieval from restored peripheral
     */
    private func onRetrieveCharacteristics(characteristics: [CBCharacteristic], peripheral: CBPeripheral, error: Error?) {
        //        // Debugging
        //        for characteristic in characteristics {
        //            log.v("Did read  characteristic: \(characteristic)", .blec)
        //            if characteristic.properties.contains(.read) {
        //                log.v("\(characteristic.uuid): properties contains .read", .blec)
        //            }
        //        }

        if characteristics.count != 3 {
            log.e("Suspicious characteristics count. Should be 3: \(characteristics.count). Exit.", .blec)
            return
        }

        if !delegates.evaluate({ $0.onDiscoverCaracteristics(characteristics, peripheral: peripheral, error: error)}) {
            log.e("One or more characteristics were not handled", .blec)
        }
    }

    /**
     * Common entry point for "normal" connection and restored connected peripheral
     */
    private func onPeripheralConnected(_ peripheral: CBPeripheral) {
        peripheral.delegate = self
        delegates.forEach { $0.onConnectPeripheral(peripheral) }

        // Called after explicit connection request or on state restoration (app was killed by system)
        // (given that when the app was killed, there was a pending connection request)
        // note on restoring case: the app is relaunched in the background only to handle this request
        startDiscovery(peripheral)
    }
}

extension BleCentralImpl: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state.toBleState()
        log.d("Central ble state: \(state)", .blec)
        statusSubject.send(state)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi: NSNumber) {

        if verboseLogThrottler / 400 == 1 {
            log.v("Discovered peripheral: \(peripheral), rssi: \(rssi)", .blec)
            verboseLogThrottler = 0
        }
        verboseLogThrottler = verboseLogThrottler + 1

        guard let centralManager = centralManager else {
            // This probably should be a fatal error, but leaving it in case it happens e.g. when exiting the app.
            // Keep an eye on this on cloud logs.
            log.e("Critical (race condition?): discovered a peripheral but central isn't set. Exit.", .blec)
            return
        }

        delegates.forEach { $0.onDiscoverPeripheral(peripheral, advertisementData: advertisementData, rssi: rssi) }

        peripheralReferenceToPreventWarning = peripheral

        if peripheral.state != .connected && peripheral.state != .connecting {
            // TODO(pmvp) connection count limit?
            log.v("Connecting to peripheral", .blec)
            centralManager.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log.v("Central did connect to peripheral", .blec)
        onPeripheralConnected(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Connection failure is unusual, see docs:
        // "This method is invoked when a connection initiated by {@link connectPeripheral:options:} has failed to
        // complete. As connection attempts do not timeout, the failure of a connection is atypical and usually indicative of a transient issue."
        //
        // Since it's unusual and transient, we do a retry, even if peripheral here can be anybody
        // TODO(pmvp) connect retry
        // TODO(next) show user a warning. Specially important pre-mvp as the peripheral is more likely to be peer.
        //
        log.w("Central did fail to connect to peripheral: \(String(describing: error))", .blec)
        delegates.forEach { $0.onDidFailToConnectToPeripheral(peripheral) }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        log.d("Central will restore state: \(dict)", .blec, .bg)
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            log.d("Restored peripherals: \(peripherals)", .blec, .bg)

            // When restoring state (e.g. restart from Xcode while there's an active peripheral connection),
            // we get here this peripheral, with state already .connected. So .didConnect will not be called
            // so we set the delegate here.
            for peripheral in peripherals {
                if peripheral.state == .connected {
                    onPeripheralConnected(peripheral)
                }
            }

            // TODO(pmvp) test state restoration more, document exact order/flow (with did connect/discover, etc.)
            // keep in mind to check "restored by system while in bg" which seems the main use case for willRestoreState
        }
    }
}

extension BleCentralImpl: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            log.e("Error discovering services: \(error)", .blec)
        }

        guard let services = peripheral.services else { return }

        if services.isEmpty {
            log.e("Error? Peripheral: \(peripheral.identifier) has no services.", .blec)
        }

        guard let service = services.filter({ $0.uuid == CBUUID.serviceCBUUID }).first else {
            // This should be an error, because we use our service uuid as discovery filter, so it should be present.
            log.e("Discovered peripheral doesn't have our service. It has services: \(services)", .blec)
            return
        }

        log.v("Central did discover service.", .blec)
        peripheral.discoverCharacteristics(nil, for: service)

//        // If it's a restored peripheral, don't discover services again if it already did.
//        // TODO(pmvp) check that the local peripheral here is the same as the restored peripheral
//        // (i.e. that it has services, if we restart after discovery)
//        // https://apple.co/3l09b1i "Update Your Initialization Process" section
//        let alreadyDiscoveredService = peripheral.services?.contains { $0.uuid == CBUUID.serviceCBUUID } ?? false
//        if !alreadyDiscoveredService {
//            peripheral.discoverServices([CBUUID.serviceCBUUID])
//        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            log.e("Should not happen? service has no characteristics", .blec)
            return
        }

        onRetrieveCharacteristics(characteristics: characteristics, peripheral: peripheral, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        delegates.forEach { _ = $0.onReadCharacteristic(characteristic, peripheral: peripheral, error: error) }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        delegates.forEach { _ = $0.onWriteCharacteristicAck(characteristic, peripheral: peripheral, error: error) }
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        log.w("Peripheral invalidated services: \(invalidatedServices). Resetting...", .blec)
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
        delegates.forEach { _ = $0.onDisconnectPeripheral(peripheral) }
        // Trigger a connection request if peripheral goes out of range to re-connect automatically when it's in range again.
        // (connection requests don't time out.)
        // https://apple.co/3l09b1i
        log.d("Peripheral disconnected. Requesting connection again.", .blec)
        
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
            log.w("Unhandled new CB state: \(self). Defaulting to .unknown", .blec)
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
