import Foundation

class DummyViewModelProvider: ViewModelProvider {

    func meeting() -> MeetingViewModel {
        let bleManager = BleManagerImpl(peripheral: BlePeripheralNoop(), central: BleCentralNoop())
        let peerService = PeerServiceImpl(nearby: NearbyNoop(), bleManager: bleManager, bleIdService: BleIdServiceNoop())
        return MeetingViewModel(peerService: peerService, sessionService: NoopCurrentSessionService(),
                                settingsShower: NoopSettingsShower(), bleEnabledService: NoopBleEnabledService())
    }

    func session() -> SessionViewModel {
        SessionViewModel(sessionService: NoopCurrentSessionService(),
                         remoteSessionManager: NoopRemoteSessionManager(),
                         clipboard: NoopClipboard(),
                         uiNotifier: NoopUINotifier(),
                         settingsShower: NoopSettingsShower())
    }

    func home() -> HomeViewModel {
        HomeViewModel(
            sessionService: NoopCurrentSessionService(),
            uiNotifier: NoopUINotifier(),
            settingsShower: NoopSettingsShower())
    }

    func meetingCreated() -> MeetingCreatedViewModel {
        MeetingCreatedViewModel(sessionManager: NoopRemoteSessionManager(),
                                sessionService: NoopCurrentSessionService(),
                                clipboard: NoopClipboard(), uiNotifier: NoopUINotifier(),
                                settingsShower: NoopSettingsShower())
    }

    func meetingJoined() -> MeetingJoinedViewModel {
        MeetingJoinedViewModel(sessionManager: NoopRemoteSessionManager(), sessionService: NoopCurrentSessionService(),
                               clipboard: NoopClipboard(), uiNotifier: NoopUINotifier(),
                               settingsShower: NoopSettingsShower())
    }

    func settings() -> SettingsViewModel {
        SettingsViewModel()
    }

    func colocatedPairingRole() -> ColocatedPairingRoleSelectionViewModel {
        ColocatedPairingRoleSelectionViewModel(sessionService: NoopColocatedSessionService())
    }

    func remotePairingRole() -> RemotePairingRoleSelectionViewModel {
        RemotePairingRoleSelectionViewModel()
    }

    func colocatedPairingJoiner() -> ColocatedPairingJoinerViewModel {
        ColocatedPairingJoinerViewModel(passwordService: NoopColocatedPairingPasswordService())
    }

    func colocatedPassword() -> ColocatedPairingPasswordViewModel {
        ColocatedPairingPasswordViewModel(sessionService: NoopColocatedSessionService())
    }
}
