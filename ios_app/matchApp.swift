import SwiftUI

@main
struct matchApp: App {
    private let container = Dependencies().createContainer()

    init() {
        makeNavigationBarTransparentEverywhere()
    }

    var body: some Scene {
        WindowGroup {
            NavigationView {
                RootView(viewModelProvider: container)
                    .onOpenURL { url in
                        let deeplinkHandler: DeeplinkHandler = try! container.resolve()
                        deeplinkHandler.handle(link: url)
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    private func makeNavigationBarTransparentEverywhere() {
        let navigationBarAppearance = UINavigationBar.appearance()
        navigationBarAppearance.barTintColor = .clear
        navigationBarAppearance.setBackgroundImage(UIImage(), for: .default)
        navigationBarAppearance.shadowImage = UIImage()
    }
}
