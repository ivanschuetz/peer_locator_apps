import Foundation
import CoreBluetooth
import Combine

protocol BleCentral {
    var publisher: PassthroughSubject<String, Never> { get }
}

class BleCentralImpl: NSObject, BleCentral {

    let publisher = PassthroughSubject<String, Never>()

    private var centralManager: CBCentralManager!

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
}

extension BleCentralImpl: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        publisher.send("\(central.state)")
    }
}

class BleCentralNoop: NSObject, BleCentral {
    let publisher = PassthroughSubject<String, Never>()
}
