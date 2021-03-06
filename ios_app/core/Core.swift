import Foundation
import CryptoKit

protocol Bootstrapper {
    func bootstrap() -> Result<Void, ServicesError>
}

protocol SessionApi {
    func createSession(sessionId: SessionId, publicKey: PublicKey) -> Result<BackendSession, ServicesError>
    func joinSession(id: SessionId, publicKey: PublicKey) -> Result<BackendSession, ServicesError>
    func ackAndRequestSessionReady(peerId: PeerId, storedPeers: Int) -> Result<Bool, ServicesError>
    func peers(sessionId: SessionId) -> Result<BackendSession, ServicesError>
    func delete(peerId: PeerId) -> Result<(), ServicesError>
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

    func createSession(sessionId: SessionId, publicKey: PublicKey) -> Result<BackendSession, ServicesError> {
        let res = ffi_create_session(sessionId.value, publicKey.value)
        switch res.status {
        case 1: return decode(sessionJson: res.session_json)
        case 2: return .failure(.networking("Networking error. Please try again later."))
        default: return .failure(.general("Error creating session: \(res)"))
        }
    }

    func joinSession(id: SessionId, publicKey: PublicKey) -> Result<BackendSession, ServicesError> {
        log.d("Will join session with id: \(id)")
        let res = ffi_join_session(id.value, publicKey.value)
        switch res.status {
        case 1: return decode(sessionJson: res.session_json)
        case 2: return .failure(.networking("Networking error. Please try again later."))
        default: return .failure(.general("Error joining session: \(res)"))
        }
    }

    func ackAndRequestSessionReady(peerId: PeerId, storedPeers: Int) -> Result<Bool, ServicesError> {
        log.d("Will ack and request session ready, peerId: \(peerId), storedPeers: \(storedPeers)")
        let res = ffi_ack(peerId.value, Int32(storedPeers))
        switch res.status {
        case 1: return .success(res.is_ready)
        case 2: return .failure(.networking("Networking error. Please try again later."))
        default: return .failure(.general("Error acking session: \(res)"))
        }
    }

    func peers(sessionId: SessionId) -> Result<BackendSession, ServicesError> {
        let res = ffi_participants(sessionId.value)
        switch res.status {
        case 1: return decode(sessionJson: res.session_json)
        case 2: return .failure(.networking("Networking error. Please try again later."))
        default: return .failure(.general("Error fetching peers: \(res)"))
        }
    }

    func delete(peerId: PeerId) -> Result<(), ServicesError> {
        let res = ffi_delete(peerId.value)
        switch res.status {
        case 1: return .success(())
        case 2: return .failure(.networking("Networking error. Please try again later."))
        default: return .failure(.general("Error marking as deleted: \(res)"))
        }
    }

    private func decode(sessionJson: Unmanaged<CFString>) -> Result<BackendSession, ServicesError> {
        let resultString = sessionJson.toString()

        log.d("Deserializing core result: \(resultString)")

        guard let data = resultString.data(using: .utf8) else {
            return .failure(.general("Couldn't convert to utf8: \(resultString)"))
        }
        
        let decoder = JSONDecoder()

        do {
            let coreSession = try decoder.decode(FFISession.self, from: data)
            return .success(
                BackendSession(id: SessionId(value: coreSession.id),
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
