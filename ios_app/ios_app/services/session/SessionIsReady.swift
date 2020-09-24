import Foundation
import Combine

protocol SessionIsReady {
    var isReady: AnyPublisher<Bool, Never> { get }
}

class SessionIsReadyImpl: SessionIsReady {
    let isReady: AnyPublisher<Bool, Never>

    init(sessionService: CurrentSessionService ) {
        isReady = sessionService.session
            .map({ sessionRes -> Bool in
                switch sessionRes {
                case .result(.success(let session)):
                    if let session = session {
                        return session.isReady
                    } else {
                        return false
                    }
                default: return false
                }
            })
            // If we map to ready/not ready and remove duplicates, it means each event is a ready<->not ready change
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
