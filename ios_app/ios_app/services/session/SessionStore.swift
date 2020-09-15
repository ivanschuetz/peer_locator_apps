import Foundation
import Combine

protocol SessionStore {
    var session: AnyPublisher<Session?, Never> { get }

    func getSession() -> Result<Session?, ServicesError>

    func save(session: Session) -> Result<(), ServicesError>
    func clear() -> Result<(), ServicesError>
    func hasSession() -> Bool

}

class SessionStoreImpl: SessionStore {
    private let keyChain: KeyChain

    let sessionSubject: PassthroughSubject<Session?, Never> = PassthroughSubject()
    lazy var session: AnyPublisher<Session?, Never> = sessionSubject.eraseToAnyPublisher()

    init(keyChain: KeyChain) {
        self.keyChain = keyChain
    }

    func save(session: Session) -> Result<(), ServicesError> {
        keyChain.putEncodable(key: .mySessionData, value: session)
    }

    func getSession() -> Result<Session?, ServicesError> {
        keyChain.getDecodable(key: .mySessionData)
    }

    func clear() -> Result<(), ServicesError> {
        keyChain.remove(.mySessionData)
    }

    func hasSession() -> Bool {
        let loadRes: Result<Session?, ServicesError> = keyChain.getDecodable(key: .mySessionData)
        switch loadRes {
        case .success(let session): return session != nil
        case .failure(let e):
            log.e("Failure checking for session: \(e)")
            return false
        }
    }
}
