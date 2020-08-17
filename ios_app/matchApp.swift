import SwiftUI

@main
struct matchApp: App {

    private let container = Dependencies().createContainer()

    var body: some Scene {
        WindowGroup {
            TabsContainerView(homeViewModel: try! container.resolve(),
                              sessionViewModel: try! container.resolve())
        }
    }
}
