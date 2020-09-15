import Foundation

protocol LocalSessionManager {
    func initLocalSession(iCreatedIt: Bool,
                          sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError>
}

class LocalSessionInitializerImpl: LocalSessionManager {
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
}
