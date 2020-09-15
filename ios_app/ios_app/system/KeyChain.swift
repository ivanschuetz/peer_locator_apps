import Foundation
import Valet

enum KeyChainKey: String {
    case mySessionData
}

protocol KeyChain {
    func putString(_ key: KeyChainKey, value: String) -> Result<(), ServicesError>
    func getString(_ key: KeyChainKey) -> Result<String?, ServicesError>

    func putEncodable<T: Encodable>(key: KeyChainKey, value: T) -> Result<(), ServicesError>
    func getDecodable<T: Decodable>(key: KeyChainKey) -> Result<T?, ServicesError>

    func remove(_ key: KeyChainKey) -> Result<(), ServicesError>
    func removeAll() -> Result<(), ServicesError>
}

class KeyChainImpl: KeyChain {
    private let json: Json

    init(json: Json) {
        self.json = json
    }

    private let valet = Identifier(nonEmpty: "ploc").map { Valet.valet(
        with: $0,
        accessibility: .afterFirstUnlock
    )}

    func putString(_ key: KeyChainKey, value: String) -> Result<(), ServicesError> {
        guard let valet = valet else {
            return .failure(.general("Keychain not initialized"))
        }

        do {
            try valet.setString(value, forKey: key.rawValue)
            return .success(())
        } catch(let e) {
            // See https://github.com/square/Valet/issues/75 supposedly this happens only during debug. canAccessKeychain returns false with no apparent reason (device).
            let msg = "Error accessing keychain for key: \(key), error: \(e)"
            log.e(msg, .env)
            return .failure(.general(msg))
        }
    }

    func getString(_ key: KeyChainKey) -> Result<String?, ServicesError> {
        guard let valet = valet else {
            return .failure(.general("Keychain not initialized"))
        }
        do {
            return .success(try valet.string(forKey: key.rawValue))
        } catch (let e) {

            switch e {
            case KeychainError.itemNotFound: return .success(nil)
            default:
                let msg = "Error accessing keychain for key: \(key), error: \(e)"
                log.e(msg, .env)
                return .failure(.general(msg))
            }
        }
    }

    func putEncodable<T: Encodable>(key: KeyChainKey, value: T) -> Result<(), ServicesError> {
        putString(key, value: json.toJson(encodable: value))
    }

    func getDecodable<T: Decodable>(key: KeyChainKey) -> Result<T?, ServicesError> {
        let res = getString(key)
        switch res {
        case .success(let str):
            if let str = str {
                return .success(json.fromJson(json: str))
            } else {
                return .success(nil)
            }
        case .failure(let e):
            return .failure(e)
        }
    }

    func contains(_ key: KeyChainKey) -> Result<Bool, ServicesError> {
        guard let valet = valet else {
            return .failure(.general("Keychain not initialized"))
        }
        do {
            return .success(try valet.containsObject(forKey: key.rawValue))
        } catch (let e) {
            let msg = "Error accessing keychain for key: \(key), error: \(e)"
            log.e(msg, .env)
            return .failure(.general(msg))
        }
    }

    func remove(_ key: KeyChainKey) -> Result<(), ServicesError> {
        guard let valet = valet else {
            return .failure(.general("Keychain not initialized"))
        }
        do {
            try valet.removeObject(forKey: key.rawValue)
            return .success(())
        } catch (let e) {
            let msg = "Error accessing keychain for key: \(key), error: \(e)"
            log.e(msg, .env)
            return .failure(.general(msg))
        }
    }

    func removeAll() -> Result<(), ServicesError> {
        guard let valet = valet else {
            return .failure(.general("Keychain not initialized"))
        }
        do {
            try valet.removeAllObjects()
            log.d("Cleared keychain")
            return .success(())
        } catch (let e) {
            let msg = "Error accessing keychain: \(e)"
            log.e(msg, .env)
            return .failure(.general(msg))
        }
    }

    private func isAvailable() -> Bool {
        guard let valet = valet else {
            return false
        }
        return valet.canAccessKeychain()
    }
}
