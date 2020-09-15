import Foundation
import Combine
import CoreBluetooth

protocol BleEnabledService {
    var bleEnabled: AnyPublisher<Bool, Never> { get }
    func enable()
}

class BleEnabledServiceImpl: BleEnabledService {
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

class SimulatorBleEnabledServiceImpl: BleEnabledService {
    let bleEnabled: AnyPublisher<Bool, Never> = Just(true)
        .eraseToAnyPublisher()
    func enable() {}
}
