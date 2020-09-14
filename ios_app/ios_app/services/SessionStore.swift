import Foundation
import Combine

protocol SessionStore {
    var session: AnyPublisher<MySessionData?, Never> { get }

    func getSession() -> Result<MySessionData?, ServicesError>

    func save(session: MySessionData) -> Result<(), ServicesError>
    func clear() -> Result<(), ServicesError>
    func hasSession() -> Bool

    func setPeer(_ participant: Participant) -> Result<MySessionData, ServicesError>
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

    func setPeer(_ participant: Participant) -> Result<MySessionData, ServicesError> {
        switch getSession() {
        case .success(let session):
            if let session = session {
                let updated = session.withParticipant(participant: participant)
                switch save(session: updated) {
                case .success: return .success(updated)
                case .failure(let e): return .failure(e)
                }
            } else {
                let msg = "No session found to set the participant: \(participant)"
                log.e(msg, .session)
                return .failure(.general(msg))
            }
        case .failure(let e):
            let msg = "Error retrieving session to set participant: \(participant), error: \(e)"
            log.e(msg, .session)
            return .failure(.general(msg))
        }
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
