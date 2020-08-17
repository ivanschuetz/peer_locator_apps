import Dip
import UIKit

class RootWireFrame {
    private let container: DependencyContainer

    private var homeViewController: HomeViewController?

    init(container: DependencyContainer, window: UIWindow) {
        self.container = container

        let homeViewModel: HomeViewModel = try! container.resolve()
        let sessionViewModel: SessionViewModel = try! container.resolve()

        let homeViewController = HomeViewController(homeViewModel: homeViewModel,
                                                    sessionViewModel: sessionViewModel)
        window.rootViewController = homeViewController
        window.makeKeyAndVisible()

        self.homeViewController = homeViewController
    }
}
