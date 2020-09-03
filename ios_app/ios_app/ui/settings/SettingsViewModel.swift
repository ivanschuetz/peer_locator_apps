import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var settingsViewData: [IdentifiableUserSettingViewData] = []

    init() {
        settingsViewData = buildSettings()
    }

    func onAction(id: UserSettingActionId) {
        switch id {
        case .about: print("tapped about")
        case .share: print("tapped share")
        }
    }
}

struct IdentifiableUserSettingViewData: Identifiable {
    let id: Int
    let data: UserSettingViewData
}

enum UserSettingViewData {
    case textAction(text: String, id: UserSettingActionId)
}

enum UserSettingToggleId {
    case filterAlertsWithSymptoms
    case filterAlertsWithLongDuration
    case filterAlertsWithShortDistance
}

enum UserSettingActionId {
    case about
    case share
}

private func buildSettings() -> [IdentifiableUserSettingViewData] {
    [
        UserSettingViewData.textAction(text: "About", id: .about),
        UserSettingViewData.textAction(text: "Share", id: .share)
    // Note: index as id assumes hardcoded settings list, as above
    ].enumerated().map { index, data in IdentifiableUserSettingViewData(id: index, data: data) }
}
