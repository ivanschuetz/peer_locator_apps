import Foundation
import CoreBluetooth
import Combine

protocol BleCentral {
    var status: PassthroughSubject<String, Never> { get }
    var writtenMyId: PassthroughSubject<BleId, Never> { get }
    var discovered: PassthroughSubject<BleId, Never> { get }

    func stop()
}

class BleCentralImpl: NSObject, BleCentral {

    let status = PassthroughSubject<String, Never>()
    let writtenMyId = PassthroughSubject<BleId, Never>()
    let discovered = PassthroughSubject<BleId, Never>()

    private let idService: BleIdService

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?

    private var peripheralsToWriteTCNTo = Set<CBPeripheral>()

    init(idService: BleIdService) {
        self.idService = idService
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func stop() {
        peripheralsToWriteTCNTo.removeAll()
        if centralManager?.isScanning ?? false {
            centralManager?.stopScan()
        }
    }

    private func flush(_ peripheral: CBPeripheral) {
        self.peripheralsToWriteTCNTo.remove(peripheral)
    }
}

extension BleCentralImpl: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        status.send("\(central.state.asString())")

        switch central.state {
        case .poweredOn:
            centralManager.scanForPeripherals(withServices: [.serviceCBUUID])
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        peripheral.delegate = self

        if let advertisementDataServiceData = advertisementData[CBAdvertisementDataServiceDataKey]
            as? [CBUUID : Data],
            let serviceData = advertisementDataServiceData[.serviceCBUUID] {
            print("Service data: \(serviceData)")
            if let id = BleId(data: serviceData) {
                // TODO: Android should send max possible bytes. Currently 17.
                print("Ble id: \(id)")
                discovered.send(id)
            } else {
                print("Service data is not a valid id")
            }

            peripheralsToWriteTCNTo.insert(peripheral)
        }

        // TODO connection count limit?
        centralManager.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("Did connect to peripheral")
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
            NSLog("Did discover service: \(service)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        // Debugging
        for characteristic in characteristics {
          print(characteristic)
            if characteristic.properties.contains(.read) {
              print("\(characteristic.uuid): properties contains .read")
            }
        }

        if let characteristic = service.characteristics?.first(where: {
            $0.uuid == .characteristicCBUUID
        }) {
            if peripheralsToWriteTCNTo.contains(peripheral) {
                let bleId = idService.id()
                writtenMyId.send(bleId)

                print("Writing bldId: \(bleId) to: \(peripheral)")

                peripheral.writeValue(
                    bleId.data,
                    for: characteristic,
                    type: .withResponse
                )
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
                print("Received id: \(id)")
                discovered.send(id)
            } else {
                print("Characteristic had no value")
            }
          default:
            print("Unexpected characteristic UUID: \(characteristic.uuid)")
        }
    }
}

private extension CBManagerState {
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
    let status = PassthroughSubject<String, Never>()
    let writtenMyId = PassthroughSubject<BleId, Never>()
    let discovered = PassthroughSubject<BleId, Never>()
    func stop() {}
}
