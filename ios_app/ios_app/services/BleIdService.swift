import Foundation

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

    func validate(bleId: BleId) -> Bool {
        // TODO
        return false
    }
}
