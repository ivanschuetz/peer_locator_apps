import Foundation
import CoreBluetooth
import Combine

protocol BleCentral {
    var status: PassthroughSubject<String, Never> { get }
    var discovered: PassthroughSubject<BleId, Never> { get }
}

class BleCentralImpl: NSObject, BleCentral {

    let status = PassthroughSubject<String, Never>()
    let discovered = PassthroughSubject<BleId, Never>()

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
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

        centralManager.stopScan()
        centralManager.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("Did connect to peripheral")
        peripheral.discoverServices([CBUUID.serviceCBUUID])
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

        for characteristic in characteristics {
          print(characteristic)

            if characteristic.properties.contains(.read) {
              print("\(characteristic.uuid): properties contains .read")
            }

            peripheral.readValue(for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case CBUUID.characteristicCBUUID:
            if let value = characteristic.value {
                // Unwrap: We write a BleId, so we should always read a BleId
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

class BleCentralNoop: NSObject, BleCentral {
    let status = PassthroughSubject<String, Never>()
    let discovered = PassthroughSubject<BleId, Never>()
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
