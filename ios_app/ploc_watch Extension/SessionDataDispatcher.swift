import Foundation
import Combine

protocol SessionDataDispatcher {
    var session: AnyPublisher<Result<SharedSessionData?, ServicesError>, Never> { get }
    var peer: AnyPublisher<Peer, Never> { get }
}

class SessionDataDispatcherImpl: SessionDataDispatcher {
    let session: AnyPublisher<Result<SharedSessionData?, ServicesError>, Never>
    let peer: AnyPublisher<Peer, Never>

    init(phoneBridge: PhoneBridge) {
        peer = phoneBridge.messages.compactMap { message in
            message["peer"] as? Peer
        }
        .eraseToAnyPublisher()

        session = phoneBridge.messages.compactMap { message in
            message["sessionData"] as? Result<SharedSessionData?, ServicesError>
        }
        .eraseToAnyPublisher()
    }
}
