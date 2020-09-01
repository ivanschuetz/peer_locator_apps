import Foundation
import Combine

class SimulatorBleManager: BleManager {
    var discovered: AnyPublisher<BleParticipant, Never> =
        Just(BleParticipant(id: BleId(str: "123")!, distance: 90)).eraseToAnyPublisher()

    func start() {}
    func stop() {}
}
