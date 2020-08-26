import SwiftUI

@main
struct matchApp: App {

    private let container = Dependencies().createContainer()

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: try! container.resolve())
        }
    }
}
