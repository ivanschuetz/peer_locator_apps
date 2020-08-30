import Foundation
import Dip

class Dependencies {

    func createContainer() -> DependencyContainer {

        let container = DependencyContainer()

        registerPhone(container: container)
        registerViewModels(container: container)

        // Throws if components fail to instantiate
        try! container.bootstrap()

        return container
    }

    private func registerPhone(container: DependencyContainer) {
        container.register(.eagerSingleton) { PhoneBridgeImpl() as PhoneBridge }
        container.register(.singleton) { SessionDataDispatcherImpl(
            phoneBridge: try container.resolve()) as SessionDataDispatcher }
    }

    private func registerViewModels(container: DependencyContainer) {
        container.register { ContentViewModel(sessionDataDispatcher: try container.resolve()) }
    }
}
