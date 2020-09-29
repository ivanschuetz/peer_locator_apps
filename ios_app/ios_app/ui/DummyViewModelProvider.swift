import Foundation

class DummyViewModelProvider: ViewModelProvider {

    func meeting() -> MeetingViewModel {
        let peerService = DetectedPeerServiceImpl(nearby: NearbyNoop(), bleIdService: BleIdServiceNoop(),
                                                  detectedBleDeviceService: NoopDetectedDeviceFilterService())
        return MeetingViewModel(peerService: peerService, sessionManager: NoopRemoteSessionManager(),
                                bleEnabler: NoopBleEnabler(), bleState: NoopBleStateObservable(),
                                bleManager: BleManagerNoop())
    }

    func session() -> PairingTypeViewModel {
        PairingTypeViewModel()
    }

    func root() -> RootViewModel {
        RootViewModel(
            sessionService: NoopCurrentSessionService(),
            uiNotifier: NoopUINotifier())
    }

    func meetingCreated() -> MeetingCreatedViewModel {
        MeetingCreatedViewModel(sessionManager: NoopRemoteSessionManager(),
                                sessionService: NoopCurrentSessionService(),
                                clipboard: NoopClipboard(), uiNotifier: NoopUINotifier())
    }

    func meetingJoined() -> MeetingJoinedViewModel {
        MeetingJoinedViewModel(sessionManager: NoopRemoteSessionManager(), sessionService: NoopCurrentSessionService(),
                               clipboard: NoopClipboard(), uiNotifier: NoopUINotifier())
    }

    func meetingJoiner() -> RemotePairingJoinerViewModel {
        RemotePairingJoinerViewModel(sessionManager: NoopRemoteSessionManager(),
                                     sessionService: NoopCurrentSessionService(),
                                     clipboard: NoopClipboard(),
                                     uiNotifier: NoopUINotifier())
    }

    func settings() -> SettingsViewModel {
        SettingsViewModel()
    }

    func colocatedPairingRole() -> ColocatedPairingRoleSelectionViewModel {
        ColocatedPairingRoleSelectionViewModel(sessionService: NoopColocatedSessionService(),
                                               bleState: NoopBleStateObservable(),
                                               bleActivator: NoopBleActivator(),
                                               uiNotifier: NoopUINotifier())
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

    func about() -> AboutViewModel {
        AboutViewModel(email: NoopEmail(), twitterOpener: NoopTwitterOpener())
    }
}
