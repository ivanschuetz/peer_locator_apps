import Foundation
import CoreBluetooth
import Combine

protocol BlePeripheral {
    func requestStart()
    // Note: has to be called before requestStart()
    func register(delegates: [BlePeripheralDelegate])
}

class BlePeripheralImpl: NSObject, BlePeripheral {
    private var peripheralManager: CBPeripheralManager?

    // Updated when read (note that it's generated on demand / first read)
    private let idService: BleIdService

    private let status = PassthroughSubject<(CBManagerState, CBPeripheralManager), Never>()
    private let startTrigger = PassthroughSubject<(), Never>()
    private var startCancellable: AnyCancellable?

    private var delegates: [BlePeripheralDelegate] = []

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

    // Note: has to be called before requestStart()
    func register(delegates: [BlePeripheralDelegate]) {
        self.delegates = delegates
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

    private func createService() -> CBMutableService {
        let service = CBMutableService(
            type: .serviceCBUUID,
            primary: true
        )
        service.characteristics = delegates.map { $0.characteristic }
        return service
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
        if !delegates.evaluate({ $0.handleEvent(.read(uuid: request.characteristic.uuid,
                                                      request: request,
                                                      peripheral: peripheral)) }) {
            log.e("Not handled read request: \(request)", .ble)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        log.d("Peripheral received write requests (\(requests.count))", .ble)

        guard requests.count > 1 else {
            log.e("Multiple write requests TODO is this normal? Exit", .ble)
            return
        }
        guard let request = requests.first else {
            log.e("Write requests empty TODO is this normal? Exit", .ble)
            return
        }
        guard let data = request.value else {
            log.e("Request has no value. Probably error (TODO confim). Exit.", .ble)
            return
        }

        if !delegates.evaluate({ $0.handleEvent(.write(uuid: request.characteristic.uuid, data: data)) }) {
            log.e("Not handled read request: \(request)", .ble)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        log.d("Peripheral will restore state", .ble, .bg)
    }
}

class BlePeripheralNoop: NSObject, BlePeripheral {
    var receivedPeerNearbyToken = PassthroughSubject<Data, Never>()
    func requestStart() {}
    func register(delegates: [BlePeripheralDelegate]) {}
}
