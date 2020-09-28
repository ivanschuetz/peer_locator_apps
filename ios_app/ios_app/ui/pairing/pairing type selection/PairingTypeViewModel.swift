import Foundation

enum PairingTypeDestination {
    case colocated, remote, none
}

class PairingTypeViewModel: ObservableObject {
    @Published var destination: PairingTypeDestination = .none
    @Published var navigationActive: Bool = false
    @Published var showSettingsModal: Bool = false
    
    @Published var presentingSafariView = false
    @Published var safariViewUrl: URL = URL(string: "https://discourse.peerfinder.xyz")!

    func onSettingsButtonTap() {
        showSettingsModal = true
//        presentingSafariView = true
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

    deinit {
        log.d("View model deinit", .ui)
    }
}
