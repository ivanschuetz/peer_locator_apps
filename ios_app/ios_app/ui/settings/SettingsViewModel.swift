import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var settingsViewData: [IdentifiableUserSettingViewData] = []
    @Published var presentingSafariView = false
    @Published var safariViewUrl: URL = URL(string: "https://discourse.peerfinder.xyz")!

    init() {
        settingsViewData = buildSettings()
    }

    func onAction(id: UserSettingActionId) {
        switch id {
        case .community:
            presentingSafariView = true
        case .share: print("tapped share")
        }
    }

    deinit {
        log.d("View model deinit", .ui)
    }
}

struct IdentifiableUserSettingViewData: Identifiable {
    let id: Int
    let data: UserSettingViewData
}

enum UserSettingViewData {
    case action(text: String, id: UserSettingActionId)
    case navigationAction(text: String, target: UserSettingNavigationTarget)
}

enum UserSettingToggleId {
    case filterAlertsWithSymptoms
    case filterAlertsWithLongDuration
    case filterAlertsWithShortDistance
}

enum UserSettingActionId {
    case share
    case community
}

enum UserSettingNavigationTarget {
    case about
}

private func buildSettings() -> [IdentifiableUserSettingViewData] {
    [
        UserSettingViewData.navigationAction(text: "About", target: .about),
        UserSettingViewData.action(text: "Community", id: .community)
//        UserSettingViewData.action(text: "Share", id: .share)
    // Note: index as id assumes hardcoded settings list, as above
    ].enumerated().map { index, data in IdentifiableUserSettingViewData(id: index, data: data) }
}
