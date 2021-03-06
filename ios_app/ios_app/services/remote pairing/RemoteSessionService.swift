import Foundation

protocol RemoteSessionService {
    func createSession() -> Result<Session, ServicesError>
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
    }

    func createSession() -> Result<Session, ServicesError> {
//        guard !hasActiveSession() else {
//            return .failure(.general("Can't create session: there's already one."))
//        }
        localSessionManager.initLocalSession(iCreatedIt: true,
                                             sessionIdGenerator: { SessionId(
                                                value: UUID().uuidString.removeAllImmutable(where: { $0 == "-" })
                                             ) }).flatMap { session in
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
        let peerId = session.peerId
        let res = sessionApi.delete(peerId: peerId)
        switch res {
        case .success: log.d("Mark deleted success for peer id: \(peerId)", .session)
        case .failure(let e): log.e("Didn't succeed deleting session: \(e)", .session)
        }
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
            // TODO(next) crash when joining a session multiple times:
            // (with only one simulator) 1) create, 2) join, enter id, 3) delete session 4) join again, enter id, 5) crash
            // As a quick fix maybe just show a notification, and navigate to start (and clear local session?)
//            fatalError("Invalid state: there are more than 2 peers in the session: \(self)")
            log.e("Invalid state: there are more than 2 peers in the session: \(self)", .session)
            return nil
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
