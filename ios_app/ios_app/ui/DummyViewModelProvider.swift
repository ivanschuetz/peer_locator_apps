import Foundation

class DummyViewModelProvider: ViewModelProvider {

    func meeting() -> MeetingViewModel {
        let bleManager = BleManagerImpl(peripheral: BlePeripheralNoop(), central: BleCentralNoop())
        let peerService = DetectedPeerServiceImpl(nearby: NearbyNoop(), bleManager: bleManager,
                                          bleIdService: BleIdServiceNoop(),
                                          validDeviceService: NoopDetectedDeviceFilterService())
        return MeetingViewModel(peerService: peerService, sessionService: NoopCurrentSessionService(),
                                settingsShower: NoopSettingsShower(), bleEnabledService: NoopBleEnabledService())
    }

    func session() -> PairingTypeViewModel {
        PairingTypeViewModel(settingsShower: NoopSettingsShower())
    }

    func root() -> RootViewModel {
        RootViewModel(
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

    func meetingJoiner() -> RemotePairingJoinerViewModel {
        RemotePairingJoinerViewModel(sessionManager: NoopRemoteSessionManager(),
                                     sessionService: NoopCurrentSessionService(),
                                     clipboard: NoopClipboard(),
                                     uiNotifier: NoopUINotifier(),
                                     settingsShower: NoopSettingsShower())
    }

    func settings() -> SettingsViewModel {
        SettingsViewModel()
    }

    func colocatedPairingRole() -> ColocatedPairingRoleSelectionViewModel {
        ColocatedPairingRoleSelectionViewModel(sessionService: NoopColocatedSessionService())
    }

    func remotePairingRole() -> RemotePairingRoleSelectionViewModel {
        RemotePairingRoleSelectionViewModel(remoteSessionManager: NoopRemoteSessionManager(),
                                            sessionService: NoopCurrentSessionService(),
                                            uiNotifier: NoopUINotifier())
    }

    func colocatedPairingJoiner() -> ColocatedPairingJoinerViewModel {
        ColocatedPairingJoinerViewModel(passwordService: NoopColocatedPairingPasswordService(),
                                        uiNotifier: NoopUINotifier())
    }

    func colocatedPassword() -> ColocatedPairingPasswordViewModel {
        ColocatedPairingPasswordViewModel(sessionService: NoopColocatedSessionService())
    }
}
