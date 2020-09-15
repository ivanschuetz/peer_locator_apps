import Foundation

protocol RemoteSessionService {
    /**
     * Initializes a local and backend session.
     */
    func createSession() -> Result<Session, ServicesError>

    /**
     * Joins an existing backend session. This consists of the following steps:
     * - Initializing a local session (creates key pair) if it doesn't exist already.
     * TODO clarify why it would already exist? is this needed?
     * - Calling join session backend service.
     * - Storing the peer's public key returned by call.
     * - Acking to the backend that the public key was stored.
     */
    func joinSession(id: SessionId) -> Result<Session, ServicesError>

    /**
     * Retrieves the backend's session data (i.e. peer's public key) and acks to the backend
     * when the peer's public key is stored. It also marks the backend session for deletion if the
     * session is ready.
     *
     * This is used by:
     * - Session creator: The creator doesn't know when the joiner joins (uploads their public key),
     *   so it must ask for it (e.g. when the app comes to fg or by pressing a button).
     * - Session joiner: The joiner doesn't know when the creator acks receiving the joiner's key, s
     *   it also must ask for it.
     *
     * Note that the creator doesn't care specifically about the joiner's ack, as sending the ack is
     * part of joining. But if there's an error and the joiner joins without ack-ing, the next call
     * of refreshSessionData() (if successful) will ack. So creator and joiner can refresh repeatedly
     * to retry after errors, either retrieving/storing the peer's public key or ack-ing.
     *
     * @returns whether session is ready, i.e. both peers have ack-ed having stored the peer's public key
     */
    func refreshSession() -> Result<Session, ServicesError>
}

class RemoteSessionServiceImpl: RemoteSessionService {
    private let sessionApi: SessionApi
    private let localSessionManager: LocalSessionManager

    init(sessionApi: SessionApi, localSessionManager: LocalSessionManager) {
        self.sessionApi = sessionApi
        self.localSessionManager = localSessionManager

        // TODO remove
        localSessionManager.clear()
    }

    func createSession() -> Result<Session, ServicesError> {
//        guard !hasActiveSession() else {
//            return .failure(.general("Can't create session: there's already one."))
//        }
        // TODO why load or create? I remember there was a reason for this but maybe not valid anymore
        // it seems cleaner to just always create, probably deleting an existing session if present ("worst case", with error log),
        // and ensure that normally there's not already an active session here, i.e. error handlers etc. delete when needed, UI
        // doesn't allow to double tap etc.
        loadOrCreateSession(isCreate: false,
                            sessionIdGenerator: { SessionId(value: UUID().uuidString) }).flatMap { session in
            switch sessionApi
                .createSession(sessionId: session.id, publicKey: session.publicKey) {
            case .success(let backendSession):
                // when creating the session, there will be obviously no peer yet (so no ack etc.)
                // we use the same handler as the rest for consistency, as it's the same response.
                return handleSessionResult(backendSession: backendSession, session: session)
            case .failure(let e):
                log.e("Error creating backend session. Deleting local session", .session)
                if case .failure(e) = localSessionManager.clear() {
                    log.e("Error deleting local session: \(e)", .session)
                }
                return .failure(e)
            }
        }
    }

    func joinSession(id sessionId: SessionId) -> Result<Session, ServicesError> {
        loadOrCreateSession(isCreate: false, sessionIdGenerator: { sessionId }).flatMap {
            joinSession(id: sessionId, session: $0)
        }
    }

    func refreshSession() -> Result<Session, ServicesError> {
        localSessionManager.withSession {
            refreshSession($0)
        }
    }

    // MARK: private

    private func joinSession(id sessionId: SessionId,
                             session: Session) -> Result<Session, ServicesError> {
        sessionApi
            // Join returns the current peers too (like the peers call)
            .joinSession(id: sessionId, publicKey: session.publicKey)
            .flatMap { backendSession in
                handleSessionResult(backendSession: backendSession, session: session)
            }
    }

    private func refreshSession(_ session: Session) -> Result<Session, ServicesError> {
        sessionApi.peers(sessionId: session.id).flatMap { backendSession in
            handleSessionResult(backendSession: backendSession, session: session)
        }
    }

    /**
     * - Stores peer's public key, if already present in the session
     * (we could request it before peer joined, in which case there's no peer)
     * - Acks to backend that we stored the key
     * - Marks session as deleted if ack returns that session is ready (both peers ack-ed)
     */
    private func handleSessionResult(backendSession: BackendSession,
                                     session: Session) -> Result<Session, ServicesError> {
        storePeerIfPresentAndAck(backendSession: backendSession, session: session).flatMap { ready in
            return localSessionManager.saveIsReady(ready).flatMap { session in
                log.d("Updated local session ready status: \(ready)", .session)
                if ready {
                        switch markDeleted(session: session) {
                        case .success: return .success(session)
                        case .failure(let e): return .failure(e)
                        }
                } else {
                    return .success(session)
                }
            }
        }
    }

    private func markDeleted(session: Session) -> Result<(), ServicesError> {
        // TODO keep retrying if fails. It's important that the session is deleted.
        let peerId = session.peerId

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
        localSessionManager.withSession {
            ackAndRequestSessionReady(session: $0)
        }
    }

    private func ackAndRequestSessionReady(session: Session) -> Result<Bool, ServicesError> {
        sessionApi.ackAndRequestSessionReady(
            peerId: session.peerId,
            storedPeers: session.hasPeer() ? 2 : 1
        )
    }

    private func processBackendSession(_ backendSession: BackendSession) -> Result<(), ServicesError> {
        localSessionManager.withSession {
            processBackendSession(backendSession, session: $0)
        }
    }

    private func processBackendSession(_ backendSession: BackendSession,
                                       session: Session) -> Result<(), ServicesError> {
        if let peer = backendSession.determinePeer(session: session) {
            return localSessionManager.savePeer(peer).map { _ in () }
        } else {
            log.d("Backend session doesn't have peer yet.", .session)
            return .success(())
        }
    }

    private func storePeerIfPresentAndAck(backendSession: BackendSession,
                                          session: Session) -> Result<Bool, ServicesError> {
        if let peer = backendSession.determinePeer(session: session) {
            switch localSessionManager.savePeer(peer) {
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

    private func loadOrCreateSession(isCreate: Bool,
                                     sessionIdGenerator: () -> SessionId) -> Result<Session, ServicesError> {
        localSessionManager.getSession().flatMap { session in
            if let session = session {
                log.d("Loaded local session: \(session)", .session)
                return .success(session)
            } else {
                return localSessionManager.initLocalSession(iCreatedIt: isCreate,
                                                            sessionIdGenerator: sessionIdGenerator)
            }
        }
    }
}

private extension BackendSession {
    func determinePeer(session: Session) -> Peer? {
        guard keys.count < 3 else {
            fatalError("Invalid state: there are more than 2 peers in the session: \(self)")
        }

        if let peer = session.peer {
            log.w("Suspicious: trying to determine peer while session already has a peer. " +
                "Returning existing peer.", .session)
            return peer
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
            return publicKeysDifferentToMine.only.map { Peer(publicKey: $0) }
        }
    }
}

class NoopRemoteSessionService: RemoteSessionService {
    func deleteSessionLocally() -> Result<(), ServicesError> {
        .success(())
    }

    func createSession() -> Result<Session, ServicesError> {
        .failure(.general("Noop failure"))
    }

    func joinSession(id: SessionId) -> Result<Session, ServicesError> {
        .failure(.general("Noop failure"))
    }

    func refreshSession() -> Result<Session, ServicesError> {
        .failure(.general("Noop failure"))
    }

    func currentSession() -> Result<Session?, ServicesError> {
        .success(nil)
    }

    func currentSessionPeers() -> Result<[Peer]?, ServicesError> {
        .success(nil)
    }
}
