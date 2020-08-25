import Foundation
import CryptoKit

protocol Bootstrapper {
    func bootstrap() -> Result<Void, ServicesError>
}

protocol SessionApi {

    // TODO: review api here: when creating, there can't be partipants yet, so it
    // doesn't make sense to return public keys
    func createSession(sessionId: SessionId, publicKey: PublicKey) -> Result<Session, ServicesError>

    func joinSession(id: SessionId, publicKey: PublicKey) -> Result<Session, ServicesError>
    func ackAndRequestSessionReady(sessionId: SessionId, storedParticipants: Int) -> Result<SessionReady, ServicesError>
    func participants(sessionId: SessionId) -> Result<Session, ServicesError>
}

class CoreImpl: SessionApi, Bootstrapper {

    func bootstrap() -> Result<Void, ServicesError> {
        let registrationStatus = register_log_callback { logMessage in
            log(logMessage: logMessage)
        }
        NSLog("register_callback returned : %d", registrationStatus)
        // CoreLogLevel: 0 -> Trace... 4 -> Error
        let res: Int32 = ffi_bootstrap(CoreLogLevel(0), true)
        if res == 1 {
            return .success(())
        } else {
            return .failure(.general("Critical: couldn't bootstrap core"))
        }
    }

    func createSession(sessionId: SessionId, publicKey: PublicKey) -> Result<Session, ServicesError> {
        let res = ffi_create_session(sessionId.value, publicKey.value)
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

private func log(logMessage: CoreLogMessage) {
    guard let unmanagedText: Unmanaged<CFString> = logMessage.text else {
        return
    }
    let text = unmanagedText.takeRetainedValue() as String

    switch logMessage.level {
    case 0:
        log.v(text, .core)
    case 1:
        log.d(text, .core)
    case 2:
        log.i(text, .core)
    case 3:
        log.w(text, .core)
    case 4:
        log.e(text, .core)
    default:
        log.i(text, .core)
    }
}
