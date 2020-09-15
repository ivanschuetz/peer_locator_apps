import Foundation
import Combine
import CoreBluetooth

protocol BleEnabler {
    var bleEnabled: AnyPublisher<Bool, Never> { get }
    // TODO review: are we calling this at the correct times?
    func enable()
}

class BleEnablerImpl: BleEnabler {
    let bleEnabled: AnyPublisher<Bool, Never>

    init(bleCentral: BleCentral) {
        bleEnabled = bleCentral.status
            .map { $0 == .poweredOn }
            .eraseToAnyPublisher()
    }

    func enable() {
        _ = CBCentralManager(delegate: nil, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey:true])
    }
}

class SimulatorBleEnablerImpl: BleEnabler {
    let bleEnabled: AnyPublisher<Bool, Never> = Just(true)
        .eraseToAnyPublisher()
    func enable() {}
}
