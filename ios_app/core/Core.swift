import Foundation

protocol SessionApi {
    func createSession() -> Result<Session, ServicesError>
}

class CoreImpl: SessionApi {
    func createSession() -> Result<Session, ServicesError> {
        let res = create_session()
        switch res.status {
        case 1: return decode(sessionJson: res.session_json)
        default: return .failure(.general("Create session error: \(res)"))
        }
    }

    private func decode(sessionJson: Unmanaged<CFString>) -> Result<Session, ServicesError> {
        let resultValue: CFString = sessionJson.takeRetainedValue()
        let resultString = resultValue as String

        log.d("Deserializing core result: \(resultString)")

        // TODO: review safety of utf-8 force unwrap
        let data = resultString.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let coreSession = try decoder.decode(FFISession.self, from: data)
            return .success(Session(id: coreSession.id, keys: coreSession.keys.map ({
                PublicKey(str: $0)
            })))
        } catch let e {
            return .failure(.general("Core returned invalid session JSON: \(e)"))
        }
    }
}

private struct FFISession: Decodable {
    let id: String
    let keys: [String]
}
