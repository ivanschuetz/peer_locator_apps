import Foundation

enum PairingTypeDestination {
    case colocated, remote, none
}

class PairingTypeViewModel: ObservableObject {
    @Published var destination: PairingTypeDestination = .none
    @Published var navigationActive: Bool = false

    private let settingsShower: SettingsShower

    init(settingsShower: SettingsShower) {
        self.settingsShower = settingsShower
    }

    func onSettingsButtonTap() {
        settingsShower.show()
    }

    func onColocatedTap() {
        navigate(to: .colocated)
    }

    func onRemoteTap() {
        navigate(to: .remote)
    }

    private func navigate(to: PairingTypeDestination) {
        log.d("Navigating to: \(to)", .ui)
        destination = to
        navigationActive = true
    }
}
