import Foundation
import CoreBluetooth
import Combine

protocol BlePeripheral {
    var readMyId: PassthroughSubject<BleId, Never> { get }
}

class BlePeripheralImpl: NSObject, BlePeripheral {
    private var peripheralManager: CBPeripheralManager?

    // Updated when read (note that it's generated on demand / first read)
    private let idService: BleIdService

    let readMyId = PassthroughSubject<BleId, Never>()

    init(idService: BleIdService) {
        self.idService = idService
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
            let myId = idService.id()
            self.readMyId.send(myId)
            request.value = myId.data
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

class BlePeripheralNoop: NSObject, BlePeripheral {
    let readMyId = PassthroughSubject<BleId, Never>()
}
