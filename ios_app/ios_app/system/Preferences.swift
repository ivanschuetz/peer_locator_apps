import Foundation

protocol Preferences {
    func putString(key: PreferenceKey, value: String)
    func getString(key: PreferenceKey) -> String?
}

enum PreferenceKey: String {
    case bleId, peerForWidget
}

class PreferencesImpl: Preferences {
    // Share with widget
    private let userDefaults = UserDefaults(suiteName: "group.xyz.ploc.ios")

    func putString(key: PreferenceKey, value: String) {
        guard let userDefaults = userDefaults else {
            fatalError("Critical: couldn't create user defaults")
        }
        userDefaults.set(value, forKey: key.rawValue)
    }

    func getString(key: PreferenceKey) -> String? {
        guard let userDefaults = userDefaults else {
            fatalError("Critical: couldn't create user defaults")
        }
        return userDefaults.string(forKey: key.rawValue)
    }
}

