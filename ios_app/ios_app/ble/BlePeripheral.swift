import Foundation
import CoreBluetooth
import Combine

protocol NearbyTokenReceiver {
    var token: AnyPublisher<SerializedSignedNearbyToken, Never> { get }
}

protocol ColocatedPublicKeyReceiver {
    var publicKey: AnyPublisher<SerializedEncryptedPublicKey, Never> { get }
}

protocol BlePeripheral {
    var readMyId: PassthroughSubject<BleId, Never> { get }
    func requestStart()
}

class BlePeripheralImpl: NSObject, BlePeripheral, NearbyTokenReceiver, ColocatedPublicKeyReceiver {
    private var peripheralManager: CBPeripheralManager?

    // Updated when read (note that it's generated on demand / first read)
    private let idService: BleIdService

    let readMyId = PassthroughSubject<BleId, Never>()

    private let status = PassthroughSubject<(CBManagerState, CBPeripheralManager), Never>()
    private let startTrigger = PassthroughSubject<(), Never>()
    private var startCancellable: AnyCancellable?

    private let tokenSubject = CurrentValueSubject<SerializedSignedNearbyToken?, Never>(nil)
    lazy var token = tokenSubject.compactMap{ $0 }.eraseToAnyPublisher()

    private let publicKeySubject = CurrentValueSubject<SerializedEncryptedPublicKey?, Never>(nil)
    lazy var publicKey = publicKeySubject.compactMap{ $0 }.eraseToAnyPublisher()

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
                    log.d("Requested peripheral start while not powered on: \(status.toBleState())", .ble)
                }
            })
    }

    func requestStart() {
        log.v("Peripheral requestStart()", .ble)
        startTrigger.send(())
    }

    private func start(peripheralManager: CBPeripheralManager) {
        log.i("Will start peripheral", .ble)
        if !peripheralManager.isAdvertising {
            peripheralManager.add(createService())
        }
    }

    private func stop(peripheralManager: CBPeripheralManager) {
        peripheralManager.stopAdvertising()
    }

    private func restart(peripheralManager: CBPeripheralManager) {
        stop(peripheralManager: peripheralManager)
        // TODO confirm that peripheralManager.isAdvertising (used in start) is false (i.e. that stop is immediate)
        // otherwise there could be situations where the peripheral doesn't start.
        start(peripheralManager: peripheralManager)
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
        log.d("Peripheral ble state: \(state.toBleState())", .ble)
        status.send((state, peripheral))
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        log.d("Peripheral added service: \(service.uuid), characteristics: " +
            "\(String(describing: service.characteristics?.count))", .ble)
        startAdvertising()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        let errorStr = error.map { " Error: \($0)" } ?? ""
        log.v("Peripheral started advertising.\(errorStr)", .ble)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        switch request.characteristic.uuid {
        case CBUUID.characteristicCBUUID:
            handleMyMeetingPublicKeyRead(peripheral: peripheral, request: request)
        default:
            // TODO review handling
            log.e("Unexpected(?): central is reading an unknown characteristic: \(request.characteristic.uuid)", .ble)
        }
    }

    private func handleMyMeetingPublicKeyRead(peripheral: CBPeripheralManager, request: CBATTRequest) {
        if let myId = idService.id() {
            self.readMyId.send(myId)
            request.value = myId.data
            peripheral.respond(to: request, withResult: .success)

        } else {
            // TODO review handling
            // This state is valid as peripheral and central are active during colocated pairing too,
            // where normally there's no session yet
            // TODO probably we should block reading session data during colocated pairing / non-active session
            log.v("Peripheral session id was read and there was no session (TODO see comment)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        log.d("Peripheral received write requests (\(requests.count))", .ble)

        guard requests.count < 2 else {
            log.e("Multiple write requests TODO is this normal? Exit", .ble)
            return
        }
        guard let request = requests.first else {
            log.e("Write requests empty TODO is this normal? Exit", .ble)
            return
        }

        switch request.characteristic.uuid {
        case .nearbyCharacteristicCBUUID:
            handleNearbyCharacteristicWrite(data: request.value)
        case .colocatedPublicKeyCBUUID:
            handleColocatedPublicKeyWrite(data: request.value)
        default:
            log.e("Received write for unsupported characteristic. Ignoring", .ble)
            return
        }
    }

    private func handleNearbyCharacteristicWrite(data: Data?) {
        guard let data = data else {
            log.e("Nearby characteristic write has no data. Exit.", .ble)
            return
        }
        tokenSubject.send(SerializedSignedNearbyToken(data: data))
    }

    private func handleColocatedPublicKeyWrite(data: Data?) {
        guard let data = data else {
            log.e("Colocated public key has no data. Exit.", .ble)
            return
        }
        publicKeySubject.send(SerializedEncryptedPublicKey(data: data))
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        log.d("Peripheral will restore state", .ble, .bg)
    }
}

private func createService() -> CBMutableService {
    let service = CBMutableService(
        type: .serviceCBUUID,
        primary: true
    )
    service.characteristics = [createCharacteristic(), createNearbyCharacteristic(),
                               createColocatedPairingCharacteristic()]
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

private func createColocatedPairingCharacteristic() -> CBCharacteristic {
    CBMutableCharacteristic(
        type: .colocatedPublicKeyCBUUID,
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
