import Foundation
import CoreBluetooth
import Combine

protocol BlePeripheral {
    var status: AnyPublisher<BleState, Never> { get }

    // Note: has to be called before requestStart()
    func register(delegates: [BlePeripheralDelegate])
    
    func requestStart()
    func stop()
}

class BlePeripheralImpl: NSObject, BlePeripheral {
    private var peripheralManager: CBPeripheralManager?

    // Updated when read (note that it's generated on demand / first read)
    private let idService: BleIdService

    private let statusSubject = CurrentValueSubject<(BleState, CBPeripheralManager?), Never>((.poweredOff, nil))
    private var stateCancellable: AnyCancellable?
    private var startCancellable: AnyCancellable?

    private var delegates: [BlePeripheralDelegate] = []

    private let createPeripheralSubject = PassthroughSubject<(), Never>()
    private var createPeripheralCancellable: AnyCancellable?

    lazy var status: AnyPublisher<BleState, Never> = statusSubject
        .map { state, _ in state }
        .eraseToAnyPublisher()

    init(idService: BleIdService) {
        self.idService = idService
        super.init()

        stateCancellable = statusSubject.sink { [weak self] state, pm in
            if let pm = pm, state == .poweredOn {
                self?.addServiceIfNotAdded(peripheralManager: pm)
            }
        }

        createPeripheralCancellable = createPeripheralSubject
            .withLatestFrom(status)
            .sink { [weak self] state in
            if state != .poweredOn {
                self?.peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [
                   CBPeripheralManagerOptionRestoreIdentifierKey: appDomain
               ])
            }
        }
    }

    // Note: has to be called before requestStart()
    func register(delegates: [BlePeripheralDelegate]) {
        self.delegates = delegates
    }

    func requestStart() {
        log.v("Peripheral requestStart()", .ble)
        // On start we create the peripheral, since this is what triggers enable ble dialog if it's disabled.
        // we also could create a temporary CBPeripheralManager to trigger this and create ours during init
        // but then IIRC we don't get poweredOn delegate call TODO revisit/confirm
        createPeripheralSubject.send(())
    }

    func stop() {
        log.i("Stopping peripheral", .ble)
        peripheralManager?.stopAdvertising()
        peripheralManager = nil
    }

    private func addServiceIfNotAdded(peripheralManager: CBPeripheralManager) {
        if !peripheralManager.isAdvertising {
            log.i("Starting peripheral: adding service", .ble)
            // Advertising is started in the didAdd service callback
            peripheralManager.add(createService())
        } else {
            log.i("Starting peripheral: peripheral is already advertising. Doing nothing.", .ble)
        }
    }

    private func stop(peripheralManager: CBPeripheralManager) {
        peripheralManager.stopAdvertising()
    }

    private func startAdvertising() {
        log.d("Will start peripheral", .ble)
        guard let peripheralManager = peripheralManager else {
            log.e("Start advertising: no peripheral manager set. Exit.", .ble)
            return
        }
        
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [CBUUID.serviceCBUUID]
        ])
    }

    private func createService() -> CBMutableService {
        let service = CBMutableService(
            type: .serviceCBUUID,
            primary: true
        )
        let characteristics = delegates.map { $0.characteristic }
        log.d("Peripheral has \(delegates.count) delegates. Created service with characteristics: \(characteristics)",
              .ble)
        service.characteristics = characteristics
        return service
    }

}

extension BlePeripheralImpl: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let state = peripheral.state.toBleState()
        log.d("Peripheral ble state: \(state)", .ble)
        statusSubject.send((state, peripheral))
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
    let status: AnyPublisher<BleState, Never> = Just(.poweredOn).eraseToAnyPublisher()
    var receivedPeerNearbyToken = PassthroughSubject<Data, Never>()
    func requestStart() {}
    func stop() {}
    func register(delegates: [BlePeripheralDelegate]) {}
}
