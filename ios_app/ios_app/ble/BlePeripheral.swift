import Foundation
import CoreBluetooth
import Combine

protocol BlePeripheral {}

class BlePeripheralImpl: NSObject, BlePeripheral {
    private var peripheralManager: CBPeripheralManager?

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    private func startAdvertising() {
        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [CBUUID.serviceCBUUID]
        ])
    }
}

extension BlePeripheralImpl: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn: peripheral.add(createService())
        default: break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        NSLog("Peripheral added service: \(service)")
        startAdvertising()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        NSLog("Peripheral started advertising. Error?: \(String(describing: error))")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == CBUUID.characteristicCBUUID { // TODO do we really need this check?
            request.value = "Hello!".data(using: .utf8)
            peripheral.respond(to: request, withResult: .success)
        } else {
            NSLog("Unexpected(?): central is reading an unknown characteristic: \(request.characteristic.uuid)")
        }
    }
}

private func createService() -> CBMutableService {
    let service = CBMutableService(
        type: .serviceCBUUID,
        primary: true
    )
    service.characteristics = [createCharacteristic()]
    return service
}

private func createCharacteristic() -> CBCharacteristic {
    CBMutableCharacteristic(
        type: .characteristicCBUUID,
        properties: [.read],
        value: nil,
        permissions: [.readable]
    )
}
