import Foundation
import Dip

class Dependencies {

    func createContainer() -> DependencyContainer {

        let container = DependencyContainer()

        registerCore(container: container)
        registerSystem(container: container)
        registerBle(container: container)
        registerServices(container: container)
        registerViewModels(container: container)

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
    }

    private func registerBle(container: DependencyContainer) {
        container.register(.eagerSingleton) { BleCentralImpl(idService: try container.resolve()) as BleCentral }
        container.register(.eagerSingleton) { BlePeripheralImpl(idService: try container.resolve()) as BlePeripheral }
        container.register(.singleton) { BleIdServiceImpl(
            crypto: try container.resolve(),
            json: try container.resolve(),
            sessionService: try container.resolve(),
            keyChain: try container.resolve()
        ) as BleIdService }
        container.register(.eagerSingleton) { BleManagerImpl(
            peripheral: try container.resolve(),
            central: try container.resolve()
        ) as BleManager }
    }

    private func registerServices(container: DependencyContainer) {
        container.register(.singleton) { TokenService() }
        container.register(.eagerSingleton) { NearbyImpl(tokenService: try container.resolve()) as Nearby }
        container.register(.eagerSingleton) { PeerServiceImpl(nearby: try container.resolve(),
                                             bleManager: try container.resolve(),
                                             bleIdService: try container.resolve()) as PeerService }
        container.register(.singleton) { NotificationServiceImpl() as NotificationService }
        container.register(.singleton) { NotificationPermissionImpl() as NotificationPermission }
        container.register(.eagerSingleton) { NotificationsDelegate() }
        container.register(.eagerSingleton) { PeerDistanceNotificationService(
            peerService: try container.resolve(),
            notificationService: try container.resolve()
        )}
        container.register(.singleton) { SessionServiceImpl(
            sessionApi: try container.resolve(),
            crypto: try container.resolve(),
            keyChain: try container.resolve()
        ) as SessionService }
        container.register(.eagerSingleton) { P2pServiceImpl(bleManager: try container.resolve(),
                                                             sessionService: try container.resolve()) as P2pService }
        container.register(.singleton) {
            CurrentSessionServiceImpl(sessionService: try container.resolve()) as CurrentSessionService
        }
    }

    private func registerViewModels(container: DependencyContainer) {
        container.register { MeetingViewModel(peerService: try container.resolve()) }
        container.register { SessionViewModel(sessionService: try container.resolve(),
                                              clipboard: try container.resolve(),
                                              uiNotifier: try container.resolve()) }
        container.register { HomeViewModel(sessionService: try container.resolve(),
                                           uiNotifier: try container.resolve()) }
        container.register { MeetingCreatedViewModel(sessionService: try container.resolve(),
                                                     clipboard: try container.resolve(),
                                                     uiNotifier: try container.resolve()) }
        container.register { MeetingJoinedViewModel(sessionService: try container.resolve(),
                                                    clipboard: try container.resolve(),
                                                    uiNotifier: try container.resolve()) }
    }
}
