import Foundation
import Combine

protocol BleManager {
    var discovered: AnyPublisher<BlePeer, Never> { get }

    func start()
    func stop()
}

class BleManagerImpl: BleManager {

    // TODO remove?
    let discovered: AnyPublisher<BlePeer, Never>

    private let peripheral: BlePeripheral
    private let central: BleCentral

    init(peripheral: BlePeripheral, central: BleCentral) {
        self.peripheral = peripheral
        self.central = central

        discovered = central.discovered.eraseToAnyPublisher()
    }

    func start() {
        log.d("Starting ble central and peripheral", .ble)
        peripheral.requestStart()
        central.requestStart()
    }

    func stop() {
        log.d("TODO stop ble central and peripheral", .ble)
        // TODO
    }

}

// TODO probably this has to be abstracted to just "(discovered)Peer"
// come back to this after nearby switching intergrated
struct BlePeer {
    let deviceUuid: UUID
    let id: BleId
    let distance: Double
}

class BleManagerNoop: NSObject, BleManager {
    let discovered: AnyPublisher<BlePeer, Never> =
        Result.Publisher(BlePeer(deviceUuid: UUID(), id: BleId(str: "")!, distance: -1)).eraseToAnyPublisher()
    func start() {}
    func stop() {}
}
