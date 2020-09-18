import Foundation
import Combine
import CoreBluetooth

protocol BleEnabler {
    // TODO review: are we calling this at the correct times?
    func showEnableDialogIfDisabled()
}

class BleEnablerImpl: BleEnabler {
    private let activateBleWhenAppComesToFg: ActivateBleWhenAppComesToFg

    init(activateBleWhenAppComesToFg: ActivateBleWhenAppComesToFg) {
        self.activateBleWhenAppComesToFg = activateBleWhenAppComesToFg
    }

    func showEnableDialogIfDisabled() {
        activateBleWhenAppComesToFg.request()
        // This is to trigger the enable (and permission, if starting the first time) dialog if ble is not enabled
        // for now disabled as I decided to create the CBCentralManager / CBPeripheralManager on demand when starting
        // this seems cleaner, as starting triggers the delegate, where we get the updated status (.poweredOn etc.)
//        _ = CBCentralManager(delegate: nil, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
}

class SimulatorBleEnablerImpl: BleEnabler {
    let bleEnabled: AnyPublisher<Bool, Never> = Just(true)
        .eraseToAnyPublisher()
    func showEnableDialogIfDisabled() {}
}
