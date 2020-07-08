import Foundation

protocol Preferences {
    func putString(key: PreferenceKey, value: String)
    func getString(key: PreferenceKey) -> String?
}

enum PreferenceKey: String {
    case bleId
}

class PreferencesImpl: Preferences {
    func putString(key: PreferenceKey, value: String) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    func getString(key: PreferenceKey) -> String? {
        UserDefaults.standard.string(forKey: key.rawValue)
    }
}
