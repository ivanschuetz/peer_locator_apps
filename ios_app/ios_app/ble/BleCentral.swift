import Foundation
import CoreBluetooth
import Combine

protocol BleCentral {
    var statusMsg: PassthroughSubject<String, Never> { get }
    var writtenMyId: PassthroughSubject<BleId, Never> { get }
    var discovered: AnyPublisher<BleParticipant, Never> { get }

    // Starts central if status is powered on. If request is sent before status is on, it will be
    // processed when status in on.
    func requestStart()
    func stop()
}

class BleCentralImpl: NSObject, BleCentral {
    let statusMsg = PassthroughSubject<String, Never>()
    let writtenMyId = PassthroughSubject<BleId, Never>()

    let discoveredSubject = PassthroughSubject<BleParticipant, Never>()
    lazy var discovered = discoveredSubject.eraseToAnyPublisher()

    private let idService: BleIdService

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?

    private let status = PassthroughSubject<CBManagerState, Never>()
    private let startTrigger = PassthroughSubject<(), Never>()
    private var startCancellable: AnyCancellable?

    private var discoveredByUuid: [UUID : BleId] = [:]

    init(idService: BleIdService) {
        self.idService = idService
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)

        startCancellable = startTrigger
            .combineLatest(status)
            .map { _, status in status }
            .removeDuplicates()
            .sink(receiveValue: {[weak self] status in
                if status == .poweredOn {
                    self?.start()
                } else {
                    log.d("Requested central start while not powered on: \(status.asString())", .ble)
                }
            })
    }

    func requestStart() {
        startTrigger.send(())
    }

    func stop() {
        if centralManager?.isScanning ?? false {
            centralManager?.stopScan()
        }
        discoveredByUuid = [:]
    }

    private func start() {
        log.i("Will start central", .ble)
        centralManager.scanForPeripherals(withServices: [.serviceCBUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(booleanLiteral: true)
        ])
    }

    private func flush(_ peripheral: CBPeripheral) {}
}

extension BleCentralImpl: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        status.send(central.state)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi: NSNumber) {
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
}

extension BleCentralImpl: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
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
        if let characteristic = service.characteristics?.first(where: {
            $0.uuid == .characteristicCBUUID
        }) {
            peripheral.readValue(for: characteristic)
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
                // Did read id (from iOS, Android can broadcast it in advertisement, so it doesn't expose characteristic to read)
                discoveredSubject.send(BleParticipant(id: id, distance: -1)) // TODO distance
            } else {
                log.w("Characteristic had no value", .ble)
            }
          default:
            log.w("Unexpected characteristic UUID: \(characteristic.uuid)", .ble)
        }
    }
}

extension CBManagerState {
    func asString() -> String {
        switch self {
        case .unknown: return ".unknown"
        case .resetting: return ".resetting"
        case .unsupported: return ".unsupported"
        case .unauthorized: return ".unauthorized"
        case .poweredOff: return ".poweredOff"
        case .poweredOn: return ".poweredOn"
        @unknown default: return "unexpected (new) bluetooth state: \(self)"
        }
    }
}

class BleCentralNoop: NSObject, BleCentral {
    let discovered = PassthroughSubject<BleParticipant, Never>().eraseToAnyPublisher()
    let statusMsg = PassthroughSubject<String, Never>()
    let writtenMyId = PassthroughSubject<BleId, Never>()
    func requestStart() {}
    func stop() {}
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
