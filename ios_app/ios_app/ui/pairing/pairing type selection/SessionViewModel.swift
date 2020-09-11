import Foundation

class PairingTypeViewModel: ObservableObject {
    private let settingsShower: SettingsShower

    init(settingsShower: SettingsShower) {
        self.settingsShower = settingsShower
    }

    func onSettingsButtonTap() {
        settingsShower.show()
    }
}
