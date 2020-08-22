import Foundation

protocol P2pService {
    func activateSession()
}

class P2pServiceImpl: P2pService {
    private let peripheral: BlePeripheral
    private let central: BleCentral

    init(peripheral: BlePeripheral, central: BleCentral) {
        self.peripheral = peripheral
        self.central = central
    }

    func activateSession() {
        peripheral.requestStart()
        central.requestStart()
    }
    // TODO deactivate?
}
