import Foundation
import Combine

protocol SessionDataDispatcher {
    var session: AnyPublisher<Result<SharedSessionData?, ServicesError>, Never> { get }
    var peer: AnyPublisher<DetectedPeer, Never> { get }
}

class SessionDataDispatcherImpl: SessionDataDispatcher {
    let session: AnyPublisher<Result<SharedSessionData?, ServicesError>, Never>
    let peer: AnyPublisher<DetectedPeer, Never>

    init(phoneBridge: PhoneBridge) {
        peer = phoneBridge.messages.compactMap { message in
            message["peer"] as? DetectedPeer
        }
        .eraseToAnyPublisher()

        session = phoneBridge.messages.compactMap { message in
            message["sessionData"] as? Result<SharedSessionData?, ServicesError>
        }
        .eraseToAnyPublisher()
    }
}
