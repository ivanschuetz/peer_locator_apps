import Foundation

// TODO rename RemoteSessionService
protocol SessionService {
    func createSession() -> Result<SharedSessionData, ServicesError>
    func joinSession(id: SessionId) -> Result<SharedSessionData, ServicesError>

    // Fetches participants, acks having stored the participants and returns whether the session is ready
    // (all participants have stored all other participants)
    // Note: UI should allow refresh only while there's an active session,
    // thus if there's no active session, returns an error
    func refreshSessionData() -> Result<SharedSessionData, ServicesError>

    func currentSession() -> Result<SharedSessionData?, ServicesError>

    func deleteSessionLocally() -> Result<(), ServicesError>
}

class SessionServiceImpl: SessionService {
    private let sessionApi: SessionApi
    private let crypto: Crypto
    private let sessionStore: SessionStore

    init(sessionApi: SessionApi, crypto: Crypto, sessionStore: SessionStore) {
        self.sessionApi = sessionApi
        self.crypto = crypto
        self.sessionStore = sessionStore

        // TODO remove
        sessionStore.clear()
    }

    func createSession() -> Result<SharedSessionData, ServicesError> {
//        guard !hasActiveSession() else {
//            return .failure(.general("Can't create session: there's already one."))
//        }
        switch loadOrCreateSessionData(isCreate: true, sessionIdGenerator: { SessionId(value: UUID().uuidString) }) {
        case .success(let sessionData):
            return sessionApi
                .createSession(sessionId: sessionData.sessionId, publicKey: sessionData.publicKey)
                .map { _ in SharedSessionData(id: sessionData.sessionId, isReady: .no,
                                              createdByMe: sessionData.createdByMe) }
        case .failure(let e):
            return .failure(e)
        }
    }

    func deleteSessionLocally() -> Result<(), ServicesError> {
        sessionStore.clear()
    }

    private func hasActiveSession() -> Bool {
        sessionStore.hasSession()
    }

    func joinSession(id sessionId: SessionId) -> Result<SharedSessionData, ServicesError> {
        log.d("Joining session: \(sessionId)", .session)
        switch loadOrCreateSessionData(isCreate: false, sessionIdGenerator: { sessionId }) {
        case .success(let sessionData):
            let joinRes = sessionApi
                .joinSession(id: sessionId, publicKey: sessionData.publicKey)
            // Join returns the current participants too (like the participants call)
            switch joinRes {
            case .success(let session):
                let readyRes = storeParticipantsAndAck(session: session)
                log.d("Session ready: \(readyRes)", .session)
                switch readyRes {
                case .success(let ready):
                    switch ready {
                    case .yes:
                        let markDeletedRes = markDeleted(sessionData: sessionData)
                        switch markDeletedRes {
                        case .success: return .success(SharedSessionData(id: sessionData.sessionId, isReady: ready,
                                                                         createdByMe: sessionData.createdByMe))
                        case .failure(let e): return .failure(e)
                        }
                    case .no:
                        return .success(SharedSessionData(id: sessionData.sessionId, isReady: ready,
                                                          createdByMe: sessionData.createdByMe))
                    }
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
        let sessionDataRes: Result<MySessionData?, ServicesError> = sessionStore.getSession()
        switch sessionDataRes {
        case .success(let sessionData):
            if let sessionData = sessionData {
                // Retrieve participants from server and store locally
                let fetchAndStoreRes = fetchAndStoreParticipants(sessionId: sessionData.sessionId)
                switch fetchAndStoreRes {
                // Ack the participants and see whether session is ready (everyone acked all the participants)
                case .success:
                    let readyRes = ackAndRequestSessionReady()
                    switch readyRes {
                    case .success(let ready):
                        switch ready {
                        case .yes:
                            let markDeletedRes = markDeleted(sessionData: sessionData)
                            switch markDeletedRes {
                            case .success: return .success(SharedSessionData(id: sessionData.sessionId, isReady: ready,
                                                                             createdByMe: sessionData.createdByMe))
                            case .failure(let e): return .failure(e)
                            }
                        case .no:
                            return .success(SharedSessionData(id: sessionData.sessionId, isReady: ready,
                                                              createdByMe: sessionData.createdByMe))
                        }
                    case .failure(let e):
                        return .failure(e)
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

    func currentSession() -> Result<SharedSessionData?, ServicesError> {
        sessionStore.getSession().map { session in
            if let session = session {
                return SharedSessionData(id: session.sessionId,
                                         isReady: session.participant != nil ? .yes : .no,
                                         createdByMe: session.createdByMe)
            } else { // No session
                return nil
            }
        }
    }

//    func currentSessionParticipants() -> Result<Participants?, ServicesError> {
//        keyChain.getDecodable(key: .participants)
//    }

    private func markDeleted(sessionData: MySessionData) -> Result<(), ServicesError> {
        // TODO keep retrying if fails. It's important that the session is deleted.
        let peerId = sessionData.participantId

        // TODO why calls 2x logged in server? see:
//        📗 17:49:01 Called participants with session_id: A6C0884C-9365-4623-AEA4-2BB902455C4B
//        📗 17:49:01 Called ack with uuid: c9a0d5fb68efbdf65c934b5521c2150b230a03c08d8e1fcf277e2f8cfd954be2, accepted: 2
//        📗 17:49:01 Updated: 1 rows
//        📗 17:49:01 Called mark_delete with peer_id: c9a0d5fb68efbdf65c934b5521c2150b230a03c08d8e1fcf277e2f8cfd954be2
//        📗 17:49:01 Called mark_delete with peer_id: c9a0d5fb68efbdf65c934b5521c2150b230a03c08d8e1fcf277e2f8cfd954be2
//        📗 17:49:01 Mark deleted: updated: 1 rows
//        📗 17:49:01 Mark deleted: the session has currently 2 participants
//        📗 17:49:01 Mark deleted: Not all the participants have marked as deleted yet.
//        📗 17:49:03 Called participants with session_id: A6C0884C-9365-4623-AEA4-2BB902455C4B
//        📗 17:49:03 Called ack with uuid: 53f2e202c337243f5aae52f24644fd0a0676370ce0a2f9158d54c0fc829cf72e, accepted: 2
//        📗 17:49:03 Updated: 1 rows
//        📗 17:49:03 Called mark_delete with peer_id: 53f2e202c337243f5aae52f24644fd0a0676370ce0a2f9158d54c0fc829cf72e
//        📗 17:49:03 Called mark_delete with peer_id: 53f2e202c337243f5aae52f24644fd0a0676370ce0a2f9158d54c0fc829cf72e

        let res = sessionApi.delete(peerId: peerId)
        log.d("Mark deleted result: \(res) for peer id: \(peerId)")
        return res
    }

    private func ackAndRequestSessionReady() -> Result<SessionReady, ServicesError> {
        switch sessionStore.getSession() {
        case .success(let sessionData):
            if let sessionData = sessionData {
                return sessionApi.ackAndRequestSessionReady(
                    participantId: sessionData.participantId,
                    storedParticipants: sessionData.participant == nil ? 1 : 2
                )
            } else {
                // TODO review this. Handling?
                return .failure(.general("Invalid state: no session found to ack"))
            }
        case .failure(let e):
            return .failure(e)
        }
    }

    private func processBackendSession(_ backendSession: Session) -> Result<(), ServicesError> {
        switch sessionStore.getSession() {
        case .success(let session):
            if let session = session {
                if let peer = determinePeer(backendSession: backendSession, session: session) {
                    return sessionStore.setPeer(peer).map { _ in () }
                } else {
                    log.d("Backend session doesn't have peer yet.", .session)
                    return .success(())
                }
            } else {
                let msg = "Invalid state: Received backend session but no session data stored. \(backendSession)"
                log.e(msg, .session)
                return .failure(.general(msg))
            }
        case .failure(let e):
            let msg = "Error retrieving session: \(e)"
            log.e(msg, .session)
            return .failure(.general(msg))
        }
    }

    private func determinePeer(backendSession: Session, session: MySessionData) -> Participant? {
        guard backendSession.keys.count < 3 else {
            fatalError("Invalid state: there are more than 2 participants in the session: \(backendSession)")
        }

        if let participant = session.participant {
            log.w("Suspicious: trying to determine partipant while session already has a participant. " +
                "Returning existing participant.", .session)
            return participant
        } else {
            let myPublicKey = session.publicKey
            let publicKeysDifferentToMine = backendSession.keys.filter {
                $0 != myPublicKey
            }
            if publicKeysDifferentToMine.count > 1 {
                // If there are max 2 keys (checked with guard), i.e. the session is meant to have 2 peers,
                // there can be just my key and my peer's key, so at most 1 key can be different to mine.
                // This implies that there can be less (i.e. 0): if the backend's session is not ready yet,
                // it will not contain the peer's key.
                fatalError("Invalid state: backend session keys don't include mine: \(backendSession)")
            }
            // only: we just checked that this list is at most 1 element length.
            return publicKeysDifferentToMine.only.map { Participant(publicKey: $0) }
        }
    }

    private func storeParticipantsAndAck(session backendSession: Session) -> Result<SessionReady, ServicesError> {
        switch sessionStore.getSession() {
        case .success(let session):
            if let session = session {
                if let peer = determinePeer(backendSession: backendSession, session: session) {
                    switch sessionStore.setPeer(peer) {
                    case .success:
                        return ackAndRequestSessionReady()
                    case .failure(let e):
                        let msg = "Error storing peer: \(e)"
                        log.e(msg, .session)
                        return .failure(.general(msg))
                    }
                } else {
                    log.v("The backend session: \(backendSession) doesn't have a peer yet. Session isn't reeady.",
                          .session)
                    return .success(.no)
                }
            } else {
                let msg = "Invalid state: Received backend session but no session data stored. \(backendSession)"
                log.e(msg, .session)
                return .failure(.general(msg))
            }
        case .failure(let e):
            let msg = "Error retrieving session: \(e)"
            log.e(msg, .session)
            return .failure(.general(msg))
        }
    }

    private func fetchAndStoreParticipants(sessionId: SessionId) -> Result<FetchAndStoreParticipantsResult, ServicesError> {
        let participantsRes = sessionApi.participants(sessionId: sessionId)
        switch participantsRes {
        case .success(let backendSession):
            switch sessionStore.getSession() {
            case .success(let session):
                if let session = session {
                    if let peer = determinePeer(backendSession: backendSession, session: session) {
                        switch sessionStore.setPeer(peer) {
                        case .success:
                            if backendSession.keys.isEmpty {
                                return .success(.fetchedNothing)
                            } else {
                                return .success(.fetchedSomething)
                            }
                        case .failure(let e):
                            let msg = "Error storing peer: \(e)"
                            log.e(msg, .session)
                            return .failure(.general(msg))
                        }
                    } else {
                        // TODO is this correct? fetched nothing? what does that mean?
                        log.v("The backend session: \(backendSession) doesn't have a peer yet. Session isn't reeady.",
                              .session)
                        return .success(.fetchedNothing)
                    }

                } else {
                    let msg = "No session stored"
                    log.e(msg, .session)
                    return .failure(.general(msg))
                }

            case .failure(let e):
                let msg = "Error retrieving session: \(e)"
                log.e(msg, .session)
                return .failure(.general(msg))
            }
        case .failure(let e):
            let msg = "Error retrieving participants from api: \(e)"
            log.e(msg, .session)
            return .failure(.general(msg))
        }
    }

    private func loadOrCreateSessionData(isCreate: Bool, sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError> {
        switch sessionStore.getSession() {
        case .success(let data):
            if let data = data {
                log.d("Loaded session data: \(data)", .session)
                return .success(data)
            } else {
                return createAndStoreSessionData(isCreate: isCreate, sessionIdGenerator: sessionIdGenerator)
            }
        case .failure(let e):
            return .failure(.general("Couldn't access keychain to load session data: \(e)"))
        }
    }

    private func createAndStoreSessionData(isCreate: Bool, sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError> {
        let keyPair = crypto.createKeyPair()
        log.d("Created key pair", .session)
        let sessionId = sessionIdGenerator()
        let sessionData = MySessionData(
            sessionId: sessionId,
            privateKey: keyPair.private_key,
            publicKey: keyPair.public_key,
            participantId: keyPair.public_key.toParticipantId(crypto: crypto),
            createdByMe: isCreate,
            participant: nil
        )
        let saveRes = sessionStore.save(session: sessionData)
        switch saveRes {
        case .success:
            return .success(sessionData)
        case .failure(let e):
            return .failure(.general("Couldn't save session data in keychain: \(e)"))
        }
    }
}

// TODO this seems weird
enum FetchAndStoreParticipantsResult {
    // Note: this currently includes the OWN participant, meaning we'll send an ack
    // just for our own key
    // this is not optimal, but for now for simplicty
    // probably we sould send ack only when we receive participants that are not ourselves
    // TODO revisit
    case fetchedSomething

    case fetchedNothing
}

class NoopSessionService: SessionService {
    func deleteSessionLocally() -> Result<(), ServicesError> {
        .success(())
    }

    func createSession() -> Result<SharedSessionData, ServicesError> {
        .success(SharedSessionData(id: SessionId(value: "123"), isReady: .no, createdByMe: true))
    }

    func joinSession(id: SessionId) -> Result<SharedSessionData, ServicesError> {
        .success(SharedSessionData(id: id, isReady: .no, createdByMe: false))
    }

    func refreshSessionData() -> Result<SharedSessionData, ServicesError> {
        .success(SharedSessionData(id: SessionId(value: "123"), isReady: .no, createdByMe: false))
    }

    func currentSession() -> Result<SharedSessionData?, ServicesError> {
        .success(nil)
    }

    func currentSessionParticipants() -> Result<Participants?, ServicesError> {
        .success(nil)
    }
}
