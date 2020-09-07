import Foundation
import CoreBluetooth
import Combine

protocol NearbyTokenReceiver {
    var token: AnyPublisher<SerializedSignedNearbyToken, Never> { get }
}

protocol BlePeripheral {
    var readMyId: PassthroughSubject<BleId, Never> { get }
    func requestStart()
}

class BlePeripheralImpl: NSObject, BlePeripheral, NearbyTokenReceiver {
    private var peripheralManager: CBPeripheralManager?

    // Updated when read (note that it's generated on demand / first read)
    private let idService: BleIdService

    let readMyId = PassthroughSubject<BleId, Never>()

    private let status = PassthroughSubject<(CBManagerState, CBPeripheralManager), Never>()
    private let startTrigger = PassthroughSubject<(), Never>()
    private var startCancellable: AnyCancellable?

    private let tokenSubject = CurrentValueSubject<SerializedSignedNearbyToken?, Never>(nil)
    lazy var token = tokenSubject.compactMap{ $0 }.eraseToAnyPublisher()

    init(idService: BleIdService) {
        self.idService = idService
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [
            CBPeripheralManagerOptionRestoreIdentifierKey: appDomain
        ])

        startCancellable = startTrigger
            .combineLatest(status)
            .map { _, status in status }
            .removeDuplicates(by: { tuple1, tuple2 in
                tuple1.0 == tuple2.0 // status change
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
        let state = peripheral.state
        log.d("Peripheral ble state: \(state)", .ble)
        status.send((state, peripheral))
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
            if let myId = idService.id() {
                self.readMyId.send(myId)
                request.value = myId.data
                peripheral.respond(to: request, withResult: .success)

            } else {
                // TODO review handling
                log.e("Illegal state: peripheral shouldn't be on without an available id. Ignoring (for now)")
                return
            }

        } else {
            // TODO review handling
            log.e("Unexpected(?): central is reading an unknown characteristic: \(request.characteristic.uuid)", .ble)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard requests.count < 2 else {
            log.e("Multiple write requests TODO is this normal? Exit", .ble)
            return
        }
        guard let request = requests.first else {
            log.e("Write requests empty TODO is this normal? Exit", .ble)
            return
        }
        guard request.characteristic.uuid == CBUUID.nearbyCharacteristicCBUUID else {
            log.e("Received write for a characteristic that's not nearby. Exit.", .ble)
            return
        }
        guard let data = request.value else {
            log.e("Nearby characteristic write has no data. Exit.", .ble)
            return
        }

        tokenSubject.send(SerializedSignedNearbyToken(data: data))
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        log.d("Peripheral will restore state: \(dict)", .ble, .bg)
    }
}

private func createService() -> CBMutableService {
    let service = CBMutableService(
        type: .serviceCBUUID,
        primary: true
    )
    service.characteristics = [createCharacteristic(), createNearbyCharacteristic()]
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

private func createNearbyCharacteristic() -> CBCharacteristic {
    CBMutableCharacteristic(
        type: .nearbyCharacteristicCBUUID,
        properties: [.write],
        value: nil,
        // TODO what is .writeEncryptionRequired / .readEncryptionRequired? does it help us?
        permissions: [.writeable]
    )
}

class BlePeripheralNoop: NSObject, BlePeripheral {
    var receivedPeerNearbyToken = PassthroughSubject<Data, Never>()
    let readMyId = PassthroughSubject<BleId, Never>()
    func requestStart() {}
}
