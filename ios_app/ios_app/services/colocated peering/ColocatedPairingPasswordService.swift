import Foundation
import Combine

// TODO rename? this is only to process deeplink password
protocol ColocatedPairingPasswordService {
    var password: AnyPublisher<ColocatedPeeringPassword, Never> { get }

    func processPassword(_ password: ColocatedPeeringPassword)
}

class ColocatedPairingPasswordServiceImpl: ColocatedPairingPasswordService {
    let passwordSubject = PassthroughSubject<ColocatedPeeringPassword, Never>()
    lazy var password = passwordSubject.eraseToAnyPublisher()

    func processPassword(_ password: ColocatedPeeringPassword) {
        passwordSubject.send(password)
    }
}

class NoopColocatedPairingPasswordService: ColocatedPairingPasswordService {
    var password: AnyPublisher<ColocatedPeeringPassword, Never> = Just(ColocatedPeeringPassword(value: "123"))
        .eraseToAnyPublisher()

    func processPassword(_ password: ColocatedPeeringPassword) {}
}
