import UIKit
import Dip

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    let container: DependencyContainer = Dependencies().createContainer()

    var window: UIWindow?

    private var rootWireframe: RootWireFrame?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        rootWireframe = RootWireFrame(container: container, window: window)
        self.window = window

        return true
    }
}
