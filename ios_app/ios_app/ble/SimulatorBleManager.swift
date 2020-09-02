import Foundation
import Combine

class SimulatorBleManager: BleManager {
    private let discoveredSubject = PassthroughSubject<BleParticipant, Never>()

    lazy var discovered: AnyPublisher<BleParticipant, Never> =
        discoveredSubject.eraseToAnyPublisher()

    func start() {
        // This is to allow to initialize a nearby session
        // NearbySessionCoordinator waits for participant validation (which is triggered by ble discovery)
        // to create the nearby session
        // this is because ble participant validation means "came in range"
        // which is when we (currently, may be changed) want to exchange the nearby tokens.
        // Assumes that start() is called after a session was created and acked
        // this assumptions is important: if we send the discovery event before,
        // there will be no private key to sign the nearby token.
        discoveredSubject.send(BleParticipant(id: BleId(data: "fakesimulatorid".data(using: .utf8)!)!,
                                              distance: 123))
    }

    func stop() {}
}
