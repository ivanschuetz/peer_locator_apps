import Foundation
import Combine

protocol BleManager {
    func start()
    func stop()
}

class BleManagerImpl: BleManager {
    private let peripheral: BlePeripheral
    private let central: BleCentral

    init(peripheral: BlePeripheral, central: BleCentral) {
        self.peripheral = peripheral
        self.central = central
    }

    func start() {
        log.d("Ble manager starting ble components...", .ble)
        peripheral.requestStart()
        central.requestStart()
    }

    // TODO should we call stop (in the central/peripheral probably) when .poweredOff? or is it the other way,
    // that when we stop we get .poweredOff event?
    func stop() {
        log.d("Ble manager stopping ble components...", .ble)
        peripheral.stop()
        central.stop()
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
