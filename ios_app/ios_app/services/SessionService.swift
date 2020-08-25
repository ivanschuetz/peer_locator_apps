import Foundation

protocol SessionService {
    func createSession() -> Result<SharedSessionData, ServicesError>
    func joinSession(link: SessionLink) -> Result<SharedSessionData, ServicesError>

    // Fetches participants, acks having stored the participants and returns whether the session is ready
    // (all participants have stored all other participants)
    // Note: UI should allow refresh only while there's an active session,
    // thus if there's no active session, returns an error
    func refreshSessionData() -> Result<SharedSessionData, ServicesError>

    func currentSession() -> Result<SharedSessionData?, ServicesError>

    func currentSessionParticipants() -> Result<Participants?, ServicesError>
}

class SessionServiceImpl: SessionService {
    private let sessionApi: SessionApi
    private let crypto: Crypto
    private let keyChain: KeyChain

    init(sessionApi: SessionApi, crypto: Crypto, keyChain: KeyChain) {
        self.sessionApi = sessionApi
        self.crypto = crypto
        self.keyChain = keyChain
//        keyChain.removeAll()
    }

    func createSession() -> Result<SharedSessionData, ServicesError> {
//        guard !hasActiveSession() else {
//            return .failure(.general("Can't create session: there's already one."))
//        }
        switch loadOrCreateSessionData(sessionIdGenerator: { SessionId(value: UUID().uuidString) }) {
        case .success(let sessionData):
            return sessionApi
                .createSession(sessionId: sessionData.sessionId, publicKey: sessionData.publicKey)
                .map { _ in SharedSessionData(id: sessionData.sessionId, isReady: .no) }
        case .failure(let e):
            return .failure(e)
        }
    }

    private func hasActiveSession() -> Bool {
        let loadRes: Result<MySessionData?, ServicesError> = keyChain.getDecodable(key: .mySessionData)
        switch loadRes {
        case .success(let sessionData): return sessionData != nil
        case .failure(let e):
            log.e("Failure checking for active session: \(e)")
            return false
        }
    }

    func joinSession(link: SessionLink) -> Result<SharedSessionData, ServicesError> {
        switch link.extractSessionId() {
        case .success(let sessionId):
            return joinSession(sessionId: sessionId)
        case .failure(let e):
            log.e("Can't join session: invalid link: \(link)")
            return .failure(e)
        }
    }

    private func joinSession(sessionId: SessionId) -> Result<SharedSessionData, ServicesError> {
        switch loadOrCreateSessionData(sessionIdGenerator: { sessionId }) {
        case .success(let sessionData):
            let joinRes = sessionApi
                .joinSession(id: sessionId, publicKey: sessionData.publicKey)
            // Join returns the current participants too (like the participants call)
            switch joinRes {
            case .success(let session):
                let readyRes = storeParticipantsAndAck(session: session)
                switch readyRes {
                case .success(let ready):
                    return .success(SharedSessionData(id: sessionId, isReady: ready))
                case .failure(let e):
                    return .failure(e)
                }
            case .failure(let e):
                return .failure(e)
            }
        case .failure(let e):
            return .failure(e)
        }
    }

    func refreshSessionData() -> Result<SharedSessionData, ServicesError> {
        // Retrieve locally stored session
        let sessionDataRes: Result<MySessionData?, ServicesError> = currentSession()
        switch sessionDataRes {
        case .success(let sessionData):
            if let sessionData = sessionData {
                // Retrieve participants from server and store locally
                let fetchAndStoreRes = fetchAndStoreParticipants(sessionId: sessionData.sessionId)
                switch fetchAndStoreRes {
                // Ack the participants and see whether session is ready (everyone acked all the participants)
                case .success: return ackAndRequestSessionReady().map {
                    SharedSessionData(id: sessionData.sessionId, isReady: $0)
                }
                case .failure(let e): return .failure(.general("Couldn't fetch or store participants: \(e)"))
                }
            } else {
                return .failure(.general("Invalid state: fetching participants but there's no session data."))
            }
        case .failure(let e):
            return .failure(.general("Failed fetching session data from keychain: \(e)"))
        }
    }

    func currentSession() -> Result<MySessionData?, ServicesError> {
        keyChain.getDecodable(key: .mySessionData)
    }

    func currentSession() -> Result<SharedSessionData?, ServicesError> {
        let res: Result<MySessionData?, ServicesError> = currentSession()
        let participantsRes: Result<Participants?, ServicesError> = keyChain.getDecodable(key: .participants)
        return res.flatMap { sessionData in
            switch participantsRes {
            case .success(let participants):
                return .success(sessionData.map {
                    SharedSessionData(id: $0.sessionId,
                                      isReady: participants.map { $0.participants.isEmpty ? .yes : .no } ?? .no)
                })
            case .failure(let e):
                return .failure(e)
            }
        }
    }

    func currentSessionParticipants() -> Result<Participants?, ServicesError> {
        keyChain.getDecodable(key: .participants)
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
        switch keyChain.putEncodable(key: .participants, value: Participants(participants: session.keys)) {
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
                log.d("Loaded session data: \(data)", .session)
                return .success(data)
            } else {
                return createAndStoreSessionData(sessionIdGenerator: sessionIdGenerator)
            }
        case .failure(let e):
            return .failure(.general("Couldn't access keychain to load session data: \(e)"))
        }
    }

    private func createAndStoreSessionData(sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError> {
        let keyPair = crypto.createKeyPair()
        log.d("Created key pair: \(keyPair)", .session)
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
