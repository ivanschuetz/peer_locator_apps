import Foundation
import CryptoKit

protocol SessionApi {

    // TODO: review api here: when creating, there can't be partipants yet, so it
    // doesn't make sense to return public keys
    func createSession(publicKey: PublicKey) -> Result<Session, ServicesError>

    func joinSession(id: SessionId, publicKey: PublicKey) -> Result<Session, ServicesError>
    func ackAndRequestSessionReady(sessionId: SessionId, storedParticipants: Int) -> Result<SessionReady, ServicesError>
    func participants(sessionId: SessionId) -> Result<Session, ServicesError>
}

class CoreImpl: SessionApi {
    
    func createSession(publicKey: PublicKey) -> Result<Session, ServicesError> {
        let res = ffi_create_session(publicKey.value)
        switch res.status {
        case 1: return decode(sessionJson: res.session_json)
        default: return .failure(.general("Create session error: \(res)"))
        }
    }

    func joinSession(id: SessionId, publicKey: PublicKey) -> Result<Session, ServicesError> {
        log.d("Will join session with id: \(id)")
        let res = ffi_join_session(id.value, publicKey.value)
        switch res.status {
        case 1: return decode(sessionJson: res.session_json)
        default: return .failure(.general("Join session error: \(res)"))
        }
    }

    func ackAndRequestSessionReady(sessionId: SessionId, storedParticipants: Int) -> Result<SessionReady, ServicesError> {
        log.d("Will ack and request session ready: \(sessionId), participants: \(storedParticipants)")
        let res = ffi_ack(sessionId.value, Int32(storedParticipants))
        switch res.status {
        case 1: return .success(res.is_ready ? .yes : .no)
        default: return .failure(.general("Ack error: \(res)"))
        }
    }

    func participants(sessionId: SessionId) -> Result<Session, ServicesError> {
        let res = ffi_participants(sessionId.value)
        switch res.status {
        case 1: return decode(sessionJson: res.session_json)
        default: return .failure(.general("Fetch participants error: \(res)"))
        }
    }

    private func decode(sessionJson: Unmanaged<CFString>) -> Result<Session, ServicesError> {
        let resultString = sessionJson.toString()

        log.d("Deserializing core result: \(resultString)")

        // TODO: review safety of utf-8 force unwrap
        let data = resultString.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let coreSession = try decoder.decode(FFISession.self, from: data)
            return .success(
                Session(id: SessionId(value: coreSession.id),
                        keys: coreSession.keys.map ({ PublicKey(value: $0) })))
        } catch let e {
            return .failure(.general("Core returned invalid session JSON: \(e)"))
        }
    }
}

private struct FFISession: Decodable {
    let id: String
    let keys: [String]
}

extension Unmanaged where Instance == CFString {
    func toString() -> String {
        let resultValue: CFString = takeRetainedValue()
        return resultValue as String
    }
}
