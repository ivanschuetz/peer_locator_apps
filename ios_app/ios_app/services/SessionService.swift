import Foundation

protocol SessionService {
    func createSession() -> Result<SessionLink, ServicesError>
    func joinSession(sessionId: SessionId) -> Result<SessionReady, ServicesError>

    // Fetches participants, acks having stored the participants and returns whether the session is ready
    // (all participants have stored all other participants)
    func refreshSessionData() -> Result<SessionReady, ServicesError>
}

class SessionServiceImpl: SessionService {
    private let sessionApi: SessionApi
    private let keyChain: KeyChain

    init(sessionApi: SessionApi, keyChain: KeyChain) {
        self.sessionApi = sessionApi
        self.keyChain = keyChain
    }

    func createSession() -> Result<SessionLink, ServicesError> {
        switch loadOrCreateSessionData(sessionIdGenerator: { SessionId(value: UUID().uuidString) }) {
        case .success(let sessionData):
            return sessionApi
                .createSession(publicKey: sessionData.publicKey)
                .map { _ in sessionData.sessionId.createLink() }
        case .failure(let e):
            return .failure(e)
        }
    }

    func joinSession(sessionId: SessionId) -> Result<SessionReady, ServicesError> {
        switch loadOrCreateSessionData(sessionIdGenerator: { sessionId }) {
        case .success(let sessionData):
            let joinRes = sessionApi
                .joinSession(id: sessionId, publicKey: sessionData.publicKey)
            // Join returns the current participants too (like the participants call)
            switch joinRes {
            case .success(let session):
                return storeParticipantsAndAck(session: session)
            case .failure(let e):
                return .failure(e)
            }
        case .failure(let e):
            return .failure(e)
        }
    }

    func refreshSessionData() -> Result<SessionReady, ServicesError> {
        let sessionDataRes: Result<MySessionData?, ServicesError> = keyChain.getDecodable(key: .mySessionData)
        switch sessionDataRes {
        case .success(let sessionData):
            if let sessionData = sessionData {
                let fetchAndStoreRes = fetchAndStoreParticipants(sessionId: sessionData.sessionId)
                switch fetchAndStoreRes {
                case .success: return ackAndRequestSessionReady()
                case .failure(let e): return .failure(.general("Couldn't fetch or store participants: \(e)"))
                }
            } else {
                return .failure(.general("Invalid state: fetching participants but there's no session data."))
            }
        case .failure(let e):
            return .failure(.general("Failed fetching session data from keychain: \(e)"))
        }
    }

    private func ackAndRequestSessionReady() -> Result<SessionReady, ServicesError> {
        let sessionDataRes: Result<MySessionData?, ServicesError> = keyChain.getDecodable(key: .mySessionData)
        switch sessionDataRes {
        case .success(let sessionData):
            if let sessionData = sessionData {
                let participatsRes: Result<Participants?, ServicesError> = keyChain.getDecodable(key: .participants)
                switch participatsRes {
                case .success(let participants):
                    let participantsCount = participants.map { $0.participants.count } ?? 0
                    return sessionApi.ackAndRequestSessionReady(sessionId: sessionData.sessionId,
                                                                storedParticipants: participantsCount)
                case .failure(let e):
                    return .failure(e)
                }
            } else {
                // TODO review this. Handling?
                return .failure(.general("Invalid state: no session found to ack"))
            }
        case .failure(let e):
            return .failure(e)
        }
    }

    private func storeParticipantsAndAck(session: Session) -> Result<SessionReady, ServicesError> {
        switch keyChain.putEncodable(key: .participants, value: session.keys) {
        case .success:
            return ackAndRequestSessionReady()
        case .failure(let e):
            return .failure(e)
        }
    }

    private func fetchAndStoreParticipants(sessionId: SessionId) -> Result<(), ServicesError> {
        let participantsRes = sessionApi.participants(sessionId: sessionId)
        switch participantsRes {
        case .success(let session):
            return keyChain.putEncodable(key: .participants, value: session.keys)
        case .failure(let e):
            return .failure(.general("Couldn't store participants: \(e)"))
        }
    }

    private func loadOrCreateSessionData(sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError> {
        let loadRes: Result<MySessionData?, ServicesError> =
            keyChain.getDecodable(key: .mySessionData)
        switch loadRes {
        case .success(let data):
            if let data = data {
                return .success(data)
            } else {
                return createAndStoreSessionData(sessionIdGenerator: sessionIdGenerator)
            }
        case .failure(let e):
            return .failure(.general("Couldn't access keychain to load session data: \(e)"))
        }
    }

    private func createAndStoreSessionData(sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError> {
        sessionApi.createKeyPair().flatMap { keyPair in
            let sessionId = sessionIdGenerator()
            let sessionData = MySessionData(
                sessionId: sessionId,
                privateKey: keyPair.private_key,
                publicKey: keyPair.public_key
            )
            let saveRes = keyChain.putEncodable(key: .mySessionData, value: sessionData)
            switch saveRes {
            case .success:
                return .success(sessionData)
            case .failure(let e):
                return .failure(.general("Couldn't save session data in keychain: \(e)"))
            }
        }
    }
}

private extension SessionId {
    func createLink() -> SessionLink {
        SessionLink(value: "verimeet:\\\(value)")
    }
}

enum SessionReady {
    case yes, no
}
