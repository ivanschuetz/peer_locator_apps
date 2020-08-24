import Foundation
import CoreBluetooth
import Combine

protocol BleCentral {
    var statusMsg: PassthroughSubject<String, Never> { get }
    var writtenMyId: PassthroughSubject<BleId, Never> { get }
    var discovered: PassthroughSubject<BleParticipant, Never> { get }

    // Starts central if status is powered on. If request is sent before status is on, it will be
    // processed when status in on.
    func requestStart()
    func stop()
}

class BleCentralImpl: NSObject, BleCentral {
    let statusMsg = PassthroughSubject<String, Never>()
    let writtenMyId = PassthroughSubject<BleId, Never>()
    let discovered = PassthroughSubject<BleParticipant, Never>()

    private let idService: BleIdService

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?

    private var peripheralsToWriteTCNTo = Set<CBPeripheral>()

    private let status = PassthroughSubject<CBManagerState, Never>()
    private let startTrigger = PassthroughSubject<(), Never>()
    private var startCancellable: AnyCancellable?

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
        peripheralsToWriteTCNTo.removeAll()
        if centralManager?.isScanning ?? false {
            centralManager?.stopScan()
        }
    }

    private func start() {
        log.i("Will start central", .ble)
        centralManager.scanForPeripherals(withServices: [.serviceCBUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(booleanLiteral: true)
        ])
    }

    private func flush(_ peripheral: CBPeripheral) {
        self.peripheralsToWriteTCNTo.remove(peripheral)
    }
}

extension BleCentralImpl: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        status.send(central.state)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi: NSNumber) {
        self.peripheral = peripheral
        peripheral.delegate = self

        if
            let advertisementDataServiceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID : Data],
            let serviceData = advertisementDataServiceData[.serviceCBUUID] {

            if let id = BleId(data: serviceData) {

                let txPowerLevel: Int? = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
                // TODO: Android should send max possible bytes. Currently 17.
                let distance = estimateDistance(rssi: rssi.doubleValue, txPowerLevelMaybe: txPowerLevel)

                log.d("Ble id: \(id), rssi: \(rssi), txPowerLevel: \(String(describing: txPowerLevel)), " +
                      "distance: \(distance), device: \(peripheral.identifier)", .ble)
                discovered.send(BleParticipant(id: id, distance: distance))

            } else {
                log.e("Service data is not a valid id: \(serviceData), length: \(serviceData.count)", .ble)
            }

            peripheralsToWriteTCNTo.insert(peripheral)
        }

        // TODO connection count limit?
        centralManager.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log.v("Did connect to peripheral", .ble)
        peripheral.discoverServices([CBUUID.serviceCBUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        peripheralsToWriteTCNTo.remove(peripheral)
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
            if peripheralsToWriteTCNTo.contains(peripheral) {
                if let bleId = idService.id() {
                    writtenMyId.send(bleId)

                    log.d("Writing bldId: \(bleId) to: \(peripheral)", .ble)

                    peripheral.writeValue(
                        bleId.data,
                        for: characteristic,
                        type: .withResponse
                    )
                } else {
                    // TODO review handling
                    log.e("Illegal state: central shouldn't be on without an available id. Ignoring (for now)")
                    return
                }

            } else {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case CBUUID.characteristicCBUUID:
            if let value = characteristic.value {
                // Unwrap: We send BleId, so we always expect BleId
                let id = BleId(data: value)!
                log.d("Received id: \(id)", .ble)
                // Did read id (from iOS, Android can broadcast it in advertisement, so it doesn't expose characteristic to read)
                discovered.send(BleParticipant(id: id, distance: -1)) // TODO distance
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
    let discovered = PassthroughSubject<BleParticipant, Never>()
    let statusMsg = PassthroughSubject<String, Never>()
    let writtenMyId = PassthroughSubject<BleId, Never>()
    func requestStart() {}
    func stop() {}
}

func estimateDistance(rssi: Double, txPowerLevelMaybe: Int?) -> Double {
    estimatedDistance(
        rssi: rssi,
        measuredRSSIAtOneMeter: rssiAtOneMeter(txPowerLevelMaybe: txPowerLevelMaybe)
    ) * 100 // cm
}

func rssiAtOneMeter(txPowerLevelMaybe: Int?) -> Double {
    // It seems we have to hardcode this, at least for Android
    // TODO do we have to differentiate between device brands? maybe we need a "handshake" where device
    // communicates it's power level via custom advertisement or gatt?
    return txPowerLevelMaybe.map { Double($0) } ?? -80 // measured with Android (pixel 3)
}

func estimatedDistance(rssi: Double, measuredRSSIAtOneMeter: Double) -> Double {
    guard rssi != 0 else {
        return -1
    }

    let ratio = rssi / measuredRSSIAtOneMeter;
    if (ratio < 1.0) {
      return pow(ratio, 10)
    } else {
      return 0.89976 * pow(ratio, 7.7095) + 0.111
    }
}
