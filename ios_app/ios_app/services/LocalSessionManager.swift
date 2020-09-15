import Foundation

protocol LocalSessionManager {
    func initLocalSession(iCreatedIt: Bool,
                          sessionIdGenerator: () -> SessionId) -> Result<Session, ServicesError>

    func savePeer(_ peer: Peer) -> Result<Session, ServicesError>

    func getSession() -> Result<Session?, ServicesError>
    // Differently to getSession(), we expect here to find a session. If there's none we get a failure result
    func withSession<T>(f: (Session) -> Result<T, ServicesError>) -> Result<T, ServicesError>

    func save(session: Session) -> Result<(), ServicesError>

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
                          sessionIdGenerator: () -> SessionId) -> Result<Session, ServicesError> {
        let session = createSessionData(isCreate: iCreatedIt, sessionIdGenerator: sessionIdGenerator)
        let saveRes = sessionStore.save(session: session)
        switch saveRes {
        case .success:
            return .success(session)
        case .failure(let e):
            return .failure(.general("Couldn't save session data in keychain: \(e)"))
        }
    }

    private func createSessionData(isCreate: Bool, sessionIdGenerator: () -> SessionId) -> Session {
        let keyPair = crypto.createKeyPair()
        log.d("Created key pair", .session)
        return Session(
            id: sessionIdGenerator(),
            privateKey: keyPair.privateKey,
            publicKey: keyPair.publicKey,
            peerId: keyPair.publicKey.toPeerId(crypto: crypto),
            createdByMe: isCreate,
            peer: nil
        )
    }

    func savePeer(_ peer: Peer) -> Result<Session, ServicesError> {
        switch sessionStore.getSession() {
        case .success(let session):
            if let session = session {
                let updated = session.withPeer(peer: peer)
                switch sessionStore.save(session: updated) {
                case .success: return .success(updated)
                case .failure(let e): return .failure(e)
                }
            } else {
                let msg = "No session found to set the peer: \(peer)"
                log.e(msg, .session)
                return .failure(.general(msg))
            }
        case .failure(let e):
            let msg = "Error retrieving session to set peer: \(peer), error: \(e)"
            log.e(msg, .session)
            return .failure(.general(msg))
        }
    }

    func withSession<T>(f: (Session) -> Result<T, ServicesError>) -> Result<T, ServicesError> {
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

    func getSession() -> Result<Session?, ServicesError> {
        sessionStore.getSession()
    }

    func save(session: Session) -> Result<(), ServicesError> {
        sessionStore.save(session: session)
    }

    func clear() -> Result<(), ServicesError> {
        sessionStore.clear()
    }
}
