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
                HomeView(viewModel: try! container.resolve(),
                         sessionViewModel: try! container.resolve(),
                         meetingCreatedViewModel: try! container.resolve(),
                         meetingJoinedViewModel: try! container.resolve(),
                         meetingViewModel: try! container.resolve(),
                         settingsViewModel: try! container.resolve())
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
