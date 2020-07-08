import Foundation

struct BleId: CustomDebugStringConvertible {
    let data: Data

    private let encoding: String.Encoding = .utf8

    var debugDescription: String {
        str()
    }

    init?(str: String) {
        if let data = str.data(using: encoding) {
            self.data = data
        } else {
            return nil
        }
    }

    init?(data: Data) {
        // Verify that data has expected format
        if String(data: data, encoding: encoding) == nil {
            return nil
        }
        self.data = data
    }

    func str() -> String {
        // Unwrap: We know in this struct that data was generated from a string with the same encoding.
        String(data: data, encoding: encoding)!
    }

    static func random() -> BleId {
        // Unwrap: We know here that it's safe as UUID is always utf8
        BleId(str: UUID().uuidString)!
    }
}

protocol BleIdService {
    func id() -> BleId
}

class BleIdServiceImpl: BleIdService {
    private let preferences: Preferences

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func id() -> BleId {
        // Unwrap: we know that we stored a valid id str
        preferences.getString(key: .bleId).map { BleId(str: $0)! } ?? {
            let new = BleId.random()
            preferences.putString(key: .bleId, value: new.str())
            return new
        }()
    }
}
