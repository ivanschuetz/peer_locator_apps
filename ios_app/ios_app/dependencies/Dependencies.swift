import Foundation
import Dip

protocol ViewModelProvider {
    func session() -> PairingTypeViewModel
    func root() -> RootViewModel
    func settings() -> SettingsViewModel

    func colocatedPairingRole() -> ColocatedPairingRoleSelectionViewModel
    func colocatedPairingJoiner() -> ColocatedPairingJoinerViewModel
    func colocatedPassword() -> ColocatedPairingPasswordViewModel

    func remotePairingRole() -> RemotePairingRoleSelectionViewModel
    func meetingCreated() -> MeetingCreatedViewModel
    func meetingJoined() -> MeetingJoinedViewModel
    func meetingJoiner() -> RemotePairingJoinerViewModel

    func meeting() -> MeetingViewModel
}

class Dependencies {
    func createContainer() -> DependencyContainer {

        let container = DependencyContainer()

        registerCore(container: container)
        registerSystem(container: container)
        registerBle(container: container)
        registerServices(container: container)
        registerViewModels(container: container)
        registerWatch(container: container)
        registerAccessibility(container: container)

        // Throws if components fail to instantiate
        try! container.bootstrap()

        return container
    }

    private func registerCore(container: DependencyContainer) {
        let core = CoreImpl()
        let res = core.bootstrap()
        if res.isFailure() {
            fatalError("CRITICAL: Couldn't initialize core: \(res)")
        }
        container.register(.singleton) { core as SessionApi }
    }

    private func registerSystem(container: DependencyContainer) {
        container.register(.singleton) { PreferencesImpl() as Preferences }
        container.register(.singleton) { KeyChainImpl(json: try container.resolve()) as KeyChain }
        container.register(.singleton) { JsonImpl() as Json }
        container.register(.singleton) { CryptoImpl() as Crypto }
        container.register(.singleton) { ClipboardImpl() as Clipboard }
        container.register(.singleton) { UINotifierImpl() as UINotifier }
        container.register(.singleton) { DeeplinkHandlerImpl(
            sessionManager: try container.resolve(),
            colocatedPasswordService: try container.resolve()
        ) as DeeplinkHandler }
        container.register(.singleton) { SettingsShowerImpl() as SettingsShower }
    }

    private func registerBle(container: DependencyContainer) {

        container.register(.singleton) { BleIdServiceImpl(
            localSessionManager: try container.resolve(),
            validationDataMediator: try container.resolve(),
            peerValidator: try container.resolve()
        ) as BleIdService }
        container.register(.singleton) { BleDeviceDetectorImpl() as BleDeviceDetector }
        container.register(.singleton) {
            BleValidationDataReaderImpl(idService: try container.resolve()) as BleValidationDataReader
        }
        container.register(.eagerSingleton) { BleValidationUIErrorDisplayer(uiNotifier: try container.resolve(),
                                                                            bleValidation: try container.resolve()) }

        #if arch(x86_64)
        container.register(.eagerSingleton) { SimulatorBleManager() as BleManager }
        let multipeerTokenService = container.register(.eagerSingleton) {
            MultipeerTokenServiceImpl()
        }
        container.register(multipeerTokenService, type: NearbyPairing.self)
        container.register(multipeerTokenService, type: NearbyTokenSender.self)
        container.register(.singleton) { SimulatorBleEnablerImpl() as BleEnabler }
        container.register(.singleton) { NoopBleStateObservable() as BleStateObservable }
        #else
        container.register(.eagerSingleton) { BleCentralImpl(idService: try container.resolve()) as BleCentral }

        container.register(.eagerSingleton) {
            BlePeripheralImpl(idService: try container.resolve()) as BlePeripheral
        }
        container.register(.eagerSingleton) { BleManagerImpl(
            peripheral: try container.resolve(),
            central: try container.resolve()
        ) as BleManager }

        container.register(.singleton) {
            BleEnablerImpl(activateBleWhenAppComesToFg: try container.resolve()) as BleEnabler
        }
        container.register(.singleton) { BleActivatorImpl(bleEnabler: try container.resolve(),
                                                          bleManager: try container.resolve()) as BleActivator }
        container.register(.singleton) { BleDeviceDetectorImpl() as BleDeviceDetector }
        container.register(.singleton) { BleNearbyPairing(bleValidator: try container.resolve()) as NearbyPairing }
        container.register(.singleton) { BleColocatedPairingImpl() as BleColocatedPairing }
        container.register(.eagerSingleton) { ActivateBleWhenAppComesToFgImpl(
            appEvents: try container.resolve(),
            bleManager: try container.resolve()
        ) as ActivateBleWhenAppComesToFg }
        container.register(.eagerSingleton) {
            BleStateObservableImpl(bleCentral: try container.resolve(),
                                   blePeripheral: try container.resolve()) as BleStateObservable
        }
        #endif
    }

    private func registerServices(container: DependencyContainer) {
        container.register(.singleton) { MultipeerTokenServiceImpl() }

        if isNearbySupported() {
            container.register(.eagerSingleton) { NearbyImpl() as Nearby }
        } else {
            log.i("Device doesn't support nearby. Using a Noop nearby dependency", .nearby)
            container.register(.singleton) { NearbyNoop() as Nearby }
        }
        
        container.register(.eagerSingleton) { PeerForWidgetRecorderImpl(
            peerService: try container.resolve(),
            preferences: try container.resolve(),
            json: try container.resolve()
        ) as PeerForWidgetRecorder }

        container.register(.eagerSingleton) { NearbySessionCoordinatorImpl(
            nearby: try container.resolve(),
            nearbyPairing: try container.resolve(),
            uiNotifier: try container.resolve(),
            localSessionManager: try container.resolve(),
            tokenProcessor: try container.resolve(),
            validDeviceService: try container.resolve(),
            appEvents: try container.resolve(),
            tokenSender: try container.resolve()
        ) as NearbySessionCoordinator }

        container.register(.singleton) { BleDeviceValidatorServiceImpl(
            validationDataReader: try container.resolve(),
            idService: try container.resolve()
        ) as BleDeviceValidatorService }
        container.register(.singleton) { DetectedBleDeviceFilterServiceImpl(
            deviceDetector: try container.resolve(),
            deviceValidator: try container.resolve()
        ) as DetectedBleDeviceFilterService }

        container.register(.eagerSingleton) { DetectedPeerServiceImpl(
            nearby: try container.resolve(),
            bleManager: try container.resolve(),
            bleIdService: try container.resolve(),
            validDeviceService: try container.resolve()
        ) as DetectedPeerService }

        container.register(.singleton) { LocalSessionManagerImpl(
            sessionStore: try container.resolve(),
            crypto: try container.resolve()
        ) as LocalSessionManager }
        container.register(.singleton) { NotificationServiceImpl() as NotificationService }
        container.register(.singleton) { NotificationPermissionImpl() as NotificationPermission }
        container.register(.eagerSingleton) { NotificationsDelegate() }
        container.register(.eagerSingleton) { PeerDistanceNotificationService(
            peerService: try container.resolve(),
            notificationService: try container.resolve()
        )}
        // .eagerSingleton to delete stored session on launch while developing
        container.register(.eagerSingleton) { RemoteSessionServiceImpl(
            sessionApi: try container.resolve(),
            localSessionManager: try container.resolve()
        ) as RemoteSessionService }

        container.register(.singleton) {
            CurrentSessionServiceImpl(localSessionManager: try container.resolve(),
                                      uiNotifier: try container.resolve()) as CurrentSessionService
        }
        container.register(.singleton) {
            NearbyTokenProcessorImpl(
                crypto: try container.resolve(),
                json: try container.resolve()
            ) as NearbyTokenProcessor
        }
//        container.register(.eagerSingleton) {
//            CloseSessionServiceImpl(
//                bleCentral: try container.resolve(),
//                keyChain: try container.resolve()
//            ) as CloseSessionService }

        container.register(.singleton) {
            RemoteSessionManagerImpl(
                sessionService: try container.resolve(),
                currentSessionService: try container.resolve()
            ) as RemoteSessionManager }

        container.register(.singleton) { ColocatedPairingPasswordServiceImpl() as ColocatedPairingPasswordService }
        container.register(.singleton) { ColocatedPeerMediatorImpl(
            crypto: try container.resolve()) as ColocatedPeerMediator
        }
        container.register(.singleton) { ColocatedPasswordProviderImpl() as ColocatedPasswordProvider }
        container.register(.singleton) { ColocatedSessionServiceImpl(
            meetingValidation: try container.resolve(),
            colocatedPairing: try container.resolve(),
            passwordProvider: try container.resolve(),
            passwordService: try container.resolve(),
            peerMediator: try container.resolve(),
            uiNotifier: try container.resolve(),
            sessionService: try container.resolve(),
            bleManager: try container.resolve(),
            localSessionManager: try container.resolve()
        ) as ColocatedSessionService }

        container.register(.eagerSingleton) {
            BleValidationDataMediatorImpl(crypto: try container.resolve(),
                                          json: try container.resolve()) as BleValidationDataMediator
        }
        container.register(.eagerSingleton) {
            BlePeerDataValidatorImpl(crypto: try container.resolve()) as BlePeerDataValidator
        }
        container.register(.eagerSingleton) { AppEventsImpl() as AppEvents }
        container.register(.eagerSingleton) { NearbyTokenSenderImpl(
            nearbyPairing: try container.resolve(),
            tokenProcessor: try container.resolve(),
            localSessionManager: try container.resolve(),
            uiNotifier: try container.resolve(),
            nearby: try container.resolve()
        ) as NearbyTokenSender }

        container.register(.singleton) {
            SessionStoreImpl(keyChain: try container.resolve()) as SessionStore
        }
    }

    private func registerViewModels(container: DependencyContainer) {
        container.register { MeetingViewModel(peerService: try container.resolve(),
                                              sessionService: try container.resolve(),
                                              settingsShower: try container.resolve(),
                                              bleEnabler: try container.resolve(),
                                              bleState: try container.resolve(),
                                              bleManager: try container.resolve()) }
        container.register { PairingTypeViewModel(settingsShower: try container.resolve()) }
        container.register { RootViewModel(sessionService: try container.resolve(),
                                           uiNotifier: try container.resolve(),
                                           settingsShower: try container.resolve()) }
        container.register { MeetingCreatedViewModel(sessionManager: try container.resolve(),
                                                     sessionService: try container.resolve(),
                                                     clipboard: try container.resolve(),
                                                     uiNotifier: try container.resolve(),
                                                     settingsShower: try container.resolve()) }
        container.register { MeetingJoinedViewModel(sessionManager: try container.resolve(),
                                                    sessionService: try container.resolve(),
                                                    clipboard: try container.resolve(),
                                                    uiNotifier: try container.resolve(),
                                                    settingsShower: try container.resolve()) }
        container.register { SettingsViewModel() }
        container.register { ColocatedPairingRoleSelectionViewModel(sessionService: try container.resolve(),
                                                                    bleState: try container.resolve(),
                                                                    bleActivator: try container.resolve(),
                                                                    uiNotifier: try container.resolve()) }

        container.register { ColocatedPairingPasswordViewModel(sessionService: try container.resolve()) }
        container.register { ColocatedPairingJoinerViewModel(passwordService: try container.resolve(),
                                                             uiNotifier: try container.resolve()) }
        container.register { RemotePairingRoleSelectionViewModel(
            remoteSessionManager: try container.resolve(),
            sessionService: try container.resolve(),
            uiNotifier: try container.resolve())
        }
        container.register { RemotePairingJoinerViewModel(
            sessionManager: try container.resolve(),
            sessionService: try container.resolve(),
            clipboard: try container.resolve(),
            uiNotifier: try container.resolve(),
            settingsShower: try container.resolve())
        }
    }

    private func registerWatch(container: DependencyContainer) {
        container.register(.eagerSingleton) { ConnectivityHandler() as WatchBridge }
        container.register(.eagerSingleton) { WatchEventsForwarderImpl(
            sessionService: try container.resolve(),
            watchBridge: try container.resolve(),
            peerService: try container.resolve()) as WatchEventsForwarder }
    }

    private func registerAccessibility(container: DependencyContainer) {
        container.register(.singleton) { VoiceImpl() as Voice }
//        container.register(.eagerSingleton) { LocationVoiceImpl(peerService: try container.resolve(),
//                                                                voice: try container.resolve()) as LocationVoice }
        container.register(.singleton) { SoundPlayerImpl() as SoundPlayer }
        container.register(.eagerSingleton) { PeerSoundsImpl(peerService: try container.resolve(),
                                                             soundPlayer: try container.resolve()) as PeerSounds }
    }
}

extension DependencyContainer: ViewModelProvider {

    func meeting() -> MeetingViewModel {
        try! resolve()
    }

    func session() -> PairingTypeViewModel {
        try! resolve()
    }

    func root() -> RootViewModel {
        try! resolve()
    }

    func meetingCreated() -> MeetingCreatedViewModel {
        try! resolve()
    }

    func meetingJoined() -> MeetingJoinedViewModel {
        try! resolve()
    }

    func settings() -> SettingsViewModel {
        try! resolve()
    }

    func colocatedPairingRole() -> ColocatedPairingRoleSelectionViewModel {
        try! resolve()
    }

    func colocatedPassword() -> ColocatedPairingPasswordViewModel {
        try! resolve()
    }

    func colocatedPairingJoiner() -> ColocatedPairingJoinerViewModel {
        try! resolve()
    }

    func remotePairingRole() -> RemotePairingRoleSelectionViewModel {
        try! resolve()
    }

    func meetingJoiner() -> RemotePairingJoinerViewModel {
        try! resolve()
    }
}
