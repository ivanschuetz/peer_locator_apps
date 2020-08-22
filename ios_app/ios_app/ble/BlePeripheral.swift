import Foundation
import CoreBluetooth
import Combine

protocol BlePeripheral {
    var readMyId: PassthroughSubject<BleId, Never> { get }
    func requestStart()
}

class BlePeripheralImpl: NSObject, BlePeripheral {
    private var peripheralManager: CBPeripheralManager?

    // Updated when read (note that it's generated on demand / first read)
    private let idService: BleIdService

    let readMyId = PassthroughSubject<BleId, Never>()

    private let status = PassthroughSubject<(CBManagerState, CBPeripheralManager), Never>()
    private let startTrigger = PassthroughSubject<(), Never>()
    private var startCancellable: AnyCancellable?

    init(idService: BleIdService) {
        self.idService = idService
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)

        startCancellable = startTrigger
            .combineLatest(status)
            .map { _, status in status }
            .removeDuplicates(by: { tuple1, tuple2 in
                tuple1.0 != tuple2.0 // status change
            })
            .sink(receiveValue: {[weak self] (status, peripheralManager) in
                if status == .poweredOn {
                    self?.start(peripheralManager: peripheralManager)
                } else {
                    log.d("Requested peripheral start while not powered on: \(status.asString())", .ble)
                }
            })
    }

    func requestStart() {
        startTrigger.send(())
    }

    private func start(peripheralManager: CBPeripheralManager) {
        log.i("Will start peripheral", .ble)
        peripheralManager.add(createService())
    }

    private func startAdvertising() {
        log.d("Will start peripheral", .ble)
        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [CBUUID.serviceCBUUID]
        ])
    }
}

extension BlePeripheralImpl: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        status.send((peripheral.state, peripheral))
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        log.d("Peripheral added service: \(service)", .ble)
        startAdvertising()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        let errorStr = error.map { " Error: \($0)" } ?? ""
        log.v("Peripheral started advertising.\(errorStr)", .ble)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == CBUUID.characteristicCBUUID { // TODO do we really need this check?
            let myId = idService.id()
            self.readMyId.send(myId)
            request.value = myId.data
            peripheral.respond(to: request, withResult: .success)
        } else {
            log.e("Unexpected(?): central is reading an unknown characteristic: \(request.characteristic.uuid)", .ble)
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
    func requestStart() {}
}
