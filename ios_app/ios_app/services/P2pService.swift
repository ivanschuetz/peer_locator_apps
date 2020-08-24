import Foundation

protocol P2pService {
    func activateSession()
}

class P2pServiceImpl: P2pService {
    private let bleManager: BleManager

    init(bleManager: BleManager) {
        self.bleManager = bleManager
    }

    func activateSession() {
        bleManager.start()
    }
    // TODO deactivate?
}
