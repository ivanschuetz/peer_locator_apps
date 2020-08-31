import Foundation
import Combine

protocol BleManager {
    var discovered: AnyPublisher<BleParticipant, Never> { get }

    func start()
    func stop()
}

protocol NearbyTokenSender {
    func sendDiscoveryToken(token: NearbyToken)
}

class BleManagerImpl: BleManager, NearbyTokenSender {
    let discovered: AnyPublisher<BleParticipant, Never>

    private let peripheral: BlePeripheral
    private let central: BleCentral

    init(peripheral: BlePeripheral, central: BleCentral) {
        self.peripheral = peripheral
        self.central = central

        discovered = central.discovered.eraseToAnyPublisher()
    }

    func start() {
        log.d("Starting ble central and peripheral", .ble)
        peripheral.requestStart()
        central.requestStart()
    }

    func stop() {
        log.d("TODO stop ble central and peripheral", .ble)
        // TODO
    }

    func sendDiscoveryToken(token: NearbyToken) {
        if !central.write(nearbyToken: token) {
            log.e("Couldn't write nearby token", .ble)
            // TODO handling (and ideally ensure this state can't happen)
        }
    }
}

// TODO probably this has to be abstracted to just "(discovered)Peer"
// come back to this after nearby switching intergrated
struct BleParticipant {
    let id: BleId
    let distance: Double
}


class BleManagerNoop: NSObject, BleManager {
    let discovered: AnyPublisher<BleParticipant, Never> =
        Result.Publisher(BleParticipant(id: BleId(str: "")!, distance: -1)).eraseToAnyPublisher()
    func start() {}
    func stop() {}
}
