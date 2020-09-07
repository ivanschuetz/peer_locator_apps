import SwiftUI

@main
struct ios_appApp: App {
    private let container = Dependencies().createContainer()

    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView(viewModel: try! container.resolve())
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
