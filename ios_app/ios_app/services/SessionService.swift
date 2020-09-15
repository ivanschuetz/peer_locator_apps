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
        loadOrCreateSessionData(isCreate: false,
                                sessionIdGenerator: { SessionId(value: UUID().uuidString) }).flatMap { session in
            sessionApi
                .createSession(sessionId: session.sessionId, publicKey: session.publicKey)
                .map { _ in SharedSessionData(id: session.sessionId,
                                              isReady: false,
                                              createdByMe: session.createdByMe) }
        }
    }

    func joinSession(id sessionId: SessionId) -> Result<SharedSessionData, ServicesError> {
        loadOrCreateSessionData(isCreate: false, sessionIdGenerator: { sessionId }).flatMap {
            joinSession(id: sessionId, sessionData: $0)
        }
    }

    func refreshSessionData() -> Result<SharedSessionData, ServicesError> {
        withLocalSession {
            refreshSessionData(sessionData: $0)
        }
    }

    func currentSession() -> Result<SharedSessionData?, ServicesError> {
        sessionStore.getSession().map { session in
            if let session = session {
                return SharedSessionData(id: session.sessionId,
                                         isReady: session.isReady(),
                                         createdByMe: session.createdByMe)
            } else {
                return nil
            }
        }
    }

    func deleteSessionLocally() -> Result<(), ServicesError> {
        sessionStore.clear()
    }

    // MARK: private

    private func hasActiveSession() -> Bool {
        sessionStore.hasSession()
    }

    private func joinSession(id sessionId: SessionId,
                             sessionData: MySessionData) -> Result<SharedSessionData, ServicesError> {
        sessionApi
            // Join returns the current participants too (like the participants call)
            .joinSession(id: sessionId, publicKey: sessionData.publicKey)
            .flatMap { backendSession in
                storeParticipantsAndAck(session: backendSession).flatMap { ready in
                    if ready {
                        switch markDeleted(sessionData: sessionData) {
                        case .success: return .success(SharedSessionData(id: sessionData.sessionId, isReady: ready,
                                                                         createdByMe: sessionData.createdByMe))
                        case .failure(let e): return .failure(e)
                        }
                    } else {
                        return .success(SharedSessionData(id: sessionData.sessionId, isReady: ready,
                                                          createdByMe: sessionData.createdByMe))
                    }
                }
            }
    }

    private func refreshSessionData(sessionData: MySessionData) -> Result<SharedSessionData, ServicesError> {
        // Retrieve participants from server and store locally
        fetchAndStoreParticipants(sessionId: sessionData.sessionId).flatMap { _ in
            // Ack the participants and see whether session is ready (everyone acked all the participants)
            ackAndRequestSessionReady().flatMap { ready in
                if ready {
                    let markDeletedRes = markDeleted(sessionData: sessionData)
                    switch markDeletedRes {
                    case .success: return .success(SharedSessionData(id: sessionData.sessionId, isReady: ready,
                                                                     createdByMe: sessionData.createdByMe))
                    case .failure(let e): return .failure(e)
                    }
                } else {
                    return .success(SharedSessionData(id: sessionData.sessionId, isReady: ready,
                                                      createdByMe: sessionData.createdByMe))
                }
            }
        }
    }

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

    private func ackAndRequestSessionReady() -> Result<Bool, ServicesError> {
        withLocalSession {
            ackAndRequestSessionReady(sessionData: $0)
        }
    }

    private func ackAndRequestSessionReady(sessionData: MySessionData) -> Result<Bool, ServicesError> {
        sessionApi.ackAndRequestSessionReady(
            participantId: sessionData.participantId,
            storedParticipants: sessionData.participant == nil ? 1 : 2
        )
    }

    private func processBackendSession(_ backendSession: Session) -> Result<(), ServicesError> {
        withLocalSession {
            processBackendSession(backendSession, sessionData: $0)
        }
    }

    private func processBackendSession(_ backendSession: Session,
                                       sessionData: MySessionData) -> Result<(), ServicesError> {
        if let peer = backendSession.determinePeer(session: sessionData) {
            return sessionStore.setPeer(peer).map { _ in () }
        } else {
            log.d("Backend session doesn't have peer yet.", .session)
            return .success(())
        }
    }


    private func storeParticipantsAndAck(session backendSession: Session) -> Result<Bool, ServicesError> {
        withLocalSession {
            storeParticipantsAndAck(session: backendSession, session: $0)
        }
    }

    private func storeParticipantsAndAck(session backendSession: Session,
                                         session: MySessionData) -> Result<Bool, ServicesError> {
        if let peer = backendSession.determinePeer(session: session) {
            switch sessionStore.setPeer(peer) {
            case .success:
                return ackAndRequestSessionReady()
            case .failure(let e):
                let msg = "Error storing peer: \(e)"
                log.e(msg, .session)
                return .failure(.general(msg))
            }
        } else {
            log.v("The backend session: \(backendSession) doesn't have a peer yet. Session isn't ready.",
                  .session)
            return .success(false)
        }
    }

    private func fetchAndStoreParticipants(sessionId: SessionId) -> Result<FetchAndStoreParticipantsResult, ServicesError> {
        withLocalSession { session in
            switch sessionApi.participants(sessionId: sessionId) {
            case .success(let backendSession):
                return fetchAndStoreParticipants(backendSession: backendSession, session: session)
            case .failure(let e):
                let msg = "Error retrieving participants from api: \(e)"
                log.e(msg, .session)
                return .failure(.general(msg))
            }
        }
    }

    private func fetchAndStoreParticipants(backendSession: Session,
                                           session: MySessionData) -> Result<FetchAndStoreParticipantsResult, ServicesError> {
        if let peer = backendSession.determinePeer(session: session) {
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
    }

    private func loadOrCreateSessionData(isCreate: Bool, sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError> {
        sessionStore.getSession().flatMap { session in
            if let session = session {
                log.d("Loaded local session: \(session)", .session)
                return .success(session)
            } else {
                return createAndStoreSessionData(isCreate: isCreate, sessionIdGenerator: sessionIdGenerator)
            }
        }
    }

    private func withLocalSession<T>(f: (MySessionData) -> Result<T, ServicesError>) -> Result<T, ServicesError> {
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

    private func createAndStoreSessionData(isCreate: Bool,
                                           sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError> {
        let session = createSessionData(isCreate: isCreate, sessionIdGenerator: sessionIdGenerator)
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
        .success(SharedSessionData(id: SessionId(value: "123"), isReady: false, createdByMe: true))
    }

    func joinSession(id: SessionId) -> Result<SharedSessionData, ServicesError> {
        .success(SharedSessionData(id: id, isReady: false, createdByMe: false))
    }

    func refreshSessionData() -> Result<SharedSessionData, ServicesError> {
        .success(SharedSessionData(id: SessionId(value: "123"), isReady: false, createdByMe: false))
    }

    func currentSession() -> Result<SharedSessionData?, ServicesError> {
        .success(nil)
    }

    func currentSessionParticipants() -> Result<Participants?, ServicesError> {
        .success(nil)
    }
}

private extension Session {
    func determinePeer(session: MySessionData) -> Participant? {
        guard keys.count < 3 else {
            fatalError("Invalid state: there are more than 2 participants in the session: \(self)")
        }

        if let participant = session.participant {
            log.w("Suspicious: trying to determine partipant while session already has a participant. " +
                "Returning existing participant.", .session)
            return participant
        } else {
            let myPublicKey = session.publicKey
            let publicKeysDifferentToMine = keys.filter {
                $0 != myPublicKey
            }
            if publicKeysDifferentToMine.count > 1 {
                // If there are max 2 keys (checked with guard), i.e. the session is meant to have 2 peers,
                // there can be just my key and my peer's key, so at most 1 key can be different to mine.
                // This implies that there can be less (i.e. 0): if the backend's session is not ready yet,
                // it will not contain the peer's key.
                fatalError("Invalid state: backend session keys don't include mine: \(self)")
            }
            // only: we just checked that this list is at most 1 element length.
            return publicKeysDifferentToMine.only.map { Participant(publicKey: $0) }
        }
    }
}
