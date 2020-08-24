import Foundation
import Combine

protocol BleManager {
    var discovered: AnyPublisher<BleParticipant, Never> { get }

    func start()
}

class BleManagerImpl: BleManager {
    let discovered: AnyPublisher<BleParticipant, Never>

    private let peripheral: BlePeripheral
    private let central: BleCentral

    init(peripheral: BlePeripheral, central: BleCentral) {
        self.peripheral = peripheral
        self.central = central

        discovered = central.discovered.eraseToAnyPublisher()
    }

    func start() {
        peripheral.requestStart()
        central.requestStart()
    }

    // TODO deactivate?
}

// TODO probably this has to be abstracted to just "(discovered)Peer"
// come back to this after nearby switching intergrated
struct BleParticipant {
    let id: BleId
    let distance: Double
}


class BleManagerNoop: NSObject, BleManager {
    let discovered: AnyPublisher<BleParticipant, Never> =
        Result.Publisher(BleParticipant(id: BleId(str: "")!, distance: -1)).eraseToAnyPublisher()
    func start() {}
}
