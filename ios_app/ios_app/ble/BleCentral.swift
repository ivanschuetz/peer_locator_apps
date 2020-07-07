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
        publisher.send("\(central.state.asString())")
    }
}

class BleCentralNoop: NSObject, BleCentral {
    let publisher = PassthroughSubject<String, Never>()
}

private extension CBManagerState {
    func asString() -> String {
        switch self {
        case .unknown: return ".unknown"
        case .resetting: return ".resetting"
        case .unsupported: return ".unsupported"
        case .unauthorized: return ".unauthorized"
        case .poweredOff: return ".poweredOff"
        case .poweredOn: return ".poweredOn"
        @unknown default: return "unexpected (new) bluetooth state: \(self)"
        }
    }
}
