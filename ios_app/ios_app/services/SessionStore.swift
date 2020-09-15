import Foundation
import Combine

protocol SessionStore {
    var session: AnyPublisher<MySessionData?, Never> { get }

    func getSession() -> Result<MySessionData?, ServicesError>

    func save(session: MySessionData) -> Result<(), ServicesError>
    func clear() -> Result<(), ServicesError>
    func hasSession() -> Bool

}

class SessionStoreImpl: SessionStore {
    private let keyChain: KeyChain

    let sessionSubject: PassthroughSubject<MySessionData?, Never> = PassthroughSubject()
    lazy var session: AnyPublisher<MySessionData?, Never> = sessionSubject.eraseToAnyPublisher()

    init(keyChain: KeyChain) {
        self.keyChain = keyChain
    }

    func save(session: MySessionData) -> Result<(), ServicesError> {
        keyChain.putEncodable(key: .mySessionData, value: session)
    }

    func getSession() -> Result<MySessionData?, ServicesError> {
        keyChain.getDecodable(key: .mySessionData)
    }

    func clear() -> Result<(), ServicesError> {
        keyChain.remove(.mySessionData)
    }

    func hasSession() -> Bool {
        let loadRes: Result<MySessionData?, ServicesError> = keyChain.getDecodable(key: .mySessionData)
        switch loadRes {
        case .success(let sessionData): return sessionData != nil
        case .failure(let e):
            log.e("Failure checking for session: \(e)")
            return false
        }
    }
}
