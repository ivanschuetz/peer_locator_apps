import Foundation
import Combine
import CoreBluetooth

protocol BleEnabler {
    // TODO review: are we calling this at the correct times?
    func showEnableDialogIfDisabled()
}

class BleEnablerImpl: BleEnabler {

    func showEnableDialogIfDisabled() {
        _ = CBCentralManager(delegate: nil, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
}

class SimulatorBleEnablerImpl: BleEnabler {
    let bleEnabled: AnyPublisher<Bool, Never> = Just(true)
        .eraseToAnyPublisher()
    func showEnableDialogIfDisabled() {}
}
