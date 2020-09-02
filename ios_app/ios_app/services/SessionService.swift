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
    func deleteSessionLocally() -> Result<(), ServicesError>
}

class SessionServiceImpl: SessionService {
    private let sessionApi: SessionApi
    private let crypto: Crypto
    private let keyChain: KeyChain

    init(sessionApi: SessionApi, crypto: Crypto, keyChain: KeyChain) {
        self.sessionApi = sessionApi
        self.crypto = crypto
        self.keyChain = keyChain

        // TODO remove
        keyChain.removeAll()
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
        let res = keyChain.remove(.mySessionData).flatMap {
            keyChain.remove(.participants)
        }
        log.d("Delete session locally result: \(res)")
        return res
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
        // Retrieve locally stored session
        let sessionDataRes: Result<MySessionData?, ServicesError> = currentSession()
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

    func currentSession() -> Result<MySessionData?, ServicesError> {
        keyChain.getDecodable(key: .mySessionData)
    }

    func currentSession() -> Result<SharedSessionData?, ServicesError> {
        let res: Result<MySessionData?, ServicesError> = currentSession()
        return res.flatMap { sessionData in
            if let sessionData = sessionData {
                let participantsRes: Result<Participants?, ServicesError> = keyChain.getDecodable(key: .participants)
                switch participantsRes {
                case .success(let participants):
                    return .success(
                        SharedSessionData(id: sessionData.sessionId,
                                          isReady: participants.map { $0.participants.isEmpty ? .yes : .no } ?? .no,
                                          createdByMe: sessionData.createdByMe)
                    )
                case .failure(let e):
                    return .failure(e)
                }
            } else { // No session
                return .success(nil)
            }
        }
    }

    func currentSessionParticipants() -> Result<Participants?, ServicesError> {
        keyChain.getDecodable(key: .participants)
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

    private func ackAndRequestSessionReady() -> Result<SessionReady, ServicesError> {
        let sessionDataRes: Result<MySessionData?, ServicesError> = keyChain.getDecodable(key: .mySessionData)
        switch sessionDataRes {
        case .success(let sessionData):
            if let sessionData = sessionData {
                let participatsRes: Result<Participants?, ServicesError> = keyChain.getDecodable(key: .participants)
                switch participatsRes {
                case .success(let participants):
                    let participantsCount = participants.map { $0.participants.count } ?? 0
                    return sessionApi.ackAndRequestSessionReady(participantId: sessionData.participantId,
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
        log.d("Storing participants", .session)
        switch keyChain.putEncodable(key: .participants, value: Participants(participants: session.keys)) {
        case .success:
            return ackAndRequestSessionReady()
        case .failure(let e):
            return .failure(e)
        }
    }

    private func fetchAndStoreParticipants(sessionId: SessionId) -> Result<FetchAndStoreParticipantsResult, ServicesError> {
        let participantsRes = sessionApi.participants(sessionId: sessionId)
        switch participantsRes {
        case .success(let session):
            // We store even if it's empty (shouldn't happen), for overall consistency
            switch keyChain.putEncodable(key: .participants, value: Participants(participants: session.keys)) {
            case .success:
                if session.keys.isEmpty {
                    return .success(.fetchedNothing)
                } else {
                    return .success(.fetchedSomething)
                }
            case .failure(let e):
                return .failure(.general("Couldn't store participants: \(e)"))
            }
        case .failure(let e):
            return .failure(.general("Couldn't fetch participants: \(e)"))
        }
    }

    private func loadOrCreateSessionData(isCreate: Bool, sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError> {
        let loadRes: Result<MySessionData?, ServicesError> =
            keyChain.getDecodable(key: .mySessionData)
        switch loadRes {
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
        log.d("Created key pair: \(keyPair)", .session)
        let sessionId = sessionIdGenerator()
        let sessionData = MySessionData(
            sessionId: sessionId,
            privateKey: keyPair.private_key,
            publicKey: keyPair.public_key,
            participantId: keyPair.public_key.toParticipantId(crypto: crypto),
            createdByMe: isCreate
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

enum FetchAndStoreParticipantsResult {
    // Note: this currently includes the OWN participant, meaning we'll send an ack
    // just for our own key
    // this is not optimal, but for now for simplicty
    // probably we sould send ack only when we receive participants that are not ourselves
    // TODO revisit
    case fetchedSomething

    case fetchedNothing
}
