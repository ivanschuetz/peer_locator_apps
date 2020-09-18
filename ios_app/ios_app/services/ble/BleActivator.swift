import Foundation

protocol BleActivator {
    func activate()
}

class BleActivatorImpl: BleActivator {
    private let bleEnabler: BleEnabler
    private let bleManager: BleManager

    init(bleEnabler: BleEnabler, bleManager: BleManager) {
        self.bleEnabler = bleEnabler
        self.bleManager = bleManager
    }

    func activate() {
        bleEnabler.showEnableDialogIfDisabled()
        bleManager.start()
    }
}

class NoopBleActivator: BleActivator {
    func activate() {}
}
