import Foundation

class DummyViewModelProvider: ViewModelProvider {

    func meeting() -> MeetingViewModel {
        let peerService = DetectedPeerServiceImpl(nearby: NearbyNoop(), bleIdService: BleIdServiceNoop(),
                                                  detectedBleDeviceService: NoopDetectedDeviceFilterService())
        return MeetingViewModel(peerService: peerService, sessionManager: NoopRemoteSessionManager(),
                                settingsShower: NoopSettingsShower(), bleEnabler: NoopBleEnabler(),
                                bleState: NoopBleStateObservable(), bleManager: BleManagerNoop())
    }

    func session() -> PairingTypeViewModel {
        PairingTypeViewModel(settingsShower: NoopSettingsShower())
    }

    func root() -> RootViewModel {
        RootViewModel(
            sessionService: NoopCurrentSessionService(),
            uiNotifier: NoopUINotifier(),
            settingsShower: NoopSettingsShower(),
            appEvents: NoopAppEvents())
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
        ColocatedPairingRoleSelectionViewModel(sessionService: NoopColocatedSessionService(),
                                               bleState: NoopBleStateObservable(),
                                               bleActivator: NoopBleActivator(),
                                               uiNotifier: NoopUINotifier(),
                                               settingsShower: NoopSettingsShower())
    }

    func remotePairingRole() -> RemotePairingRoleSelectionViewModel {
        RemotePairingRoleSelectionViewModel(remoteSessionManager: NoopRemoteSessionManager(),
                                            sessionService: NoopCurrentSessionService(),
                                            uiNotifier: NoopUINotifier(),
                                            settingsShower: NoopSettingsShower())
    }

    func colocatedPairingJoiner() -> ColocatedPairingJoinerViewModel {
        ColocatedPairingJoinerViewModel(passwordService: NoopColocatedPairingPasswordService(),
                                        uiNotifier: NoopUINotifier())
    }

    func colocatedPassword() -> ColocatedPairingPasswordViewModel {
        ColocatedPairingPasswordViewModel(sessionService: NoopColocatedSessionService())
    }
}
