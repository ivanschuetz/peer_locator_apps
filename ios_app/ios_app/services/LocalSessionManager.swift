import Foundation

protocol LocalSessionManager {
    func initLocalSession(iCreatedIt: Bool,
                          sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError>

    func savePeer(_ participant: Participant) -> Result<MySessionData, ServicesError>

    func getSession() -> Result<MySessionData?, ServicesError>
    // Differently to getSession(), we expect here to find a session. If there's none we get a failure result
    func withSession<T>(f: (MySessionData) -> Result<T, ServicesError>) -> Result<T, ServicesError>

    func save(session: MySessionData) -> Result<(), ServicesError>

    func clear() -> Result<(), ServicesError>
}

class LocalSessionManagerImpl: LocalSessionManager {
    private let sessionStore: SessionStore
    private let crypto: Crypto

    init(sessionStore: SessionStore, crypto: Crypto) {
        self.sessionStore = sessionStore
        self.crypto = crypto
    }

    func initLocalSession(iCreatedIt: Bool,
                          sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError> {
        let session = createSessionData(isCreate: iCreatedIt, sessionIdGenerator: sessionIdGenerator)
        let saveRes = sessionStore.save(session: session)
        switch saveRes {
        case .success:
            return .success(session)
        case .failure(let e):
            return .failure(.general("Couldn't save session data in keychain: \(e)"))
        }
    }

    private func createSessionData(isCreate: Bool, sessionIdGenerator: () -> SessionId) -> MySessionData {
        let keyPair = crypto.createKeyPair()
        log.d("Created key pair", .session)
        return MySessionData(
            sessionId: sessionIdGenerator(),
            privateKey: keyPair.private_key,
            publicKey: keyPair.public_key,
            participantId: keyPair.public_key.toParticipantId(crypto: crypto),
            createdByMe: isCreate,
            participant: nil
        )
    }

    func savePeer(_ participant: Participant) -> Result<MySessionData, ServicesError> {
        switch sessionStore.getSession() {
        case .success(let session):
            if let session = session {
                let updated = session.withParticipant(participant: participant)
                switch sessionStore.save(session: updated) {
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

    func withSession<T>(f: (MySessionData) -> Result<T, ServicesError>) -> Result<T, ServicesError> {
        sessionStore.getSession().flatMap { session in
            if let session = session {
                return f(session)
            } else {
                let msg = "Invalid state: no local session"
                log.e(msg, .session)
                return .failure(.general(msg))
            }
        }
    }

    func getSession() -> Result<MySessionData?, ServicesError> {
        sessionStore.getSession()
    }

    func save(session: MySessionData) -> Result<(), ServicesError> {
        sessionStore.save(session: session)
    }

    func clear() -> Result<(), ServicesError> {
        sessionStore.clear()
    }
}
