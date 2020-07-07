import Foundation
import CoreBluetooth
import Combine

class BleCentral: NSObject {

    let publisher = PassthroughSubject<String, Never>()

    private var centralManager: CBCentralManager!

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
}

extension BleCentral: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        publisher.send("\(central.state)")
    }
}
