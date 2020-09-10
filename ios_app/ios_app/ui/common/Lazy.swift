import SwiftUI

// Solves NavigationLink creating destination views (thus also view models) when view is loaded
// https://stackoverflow.com/a/61234030/930450

struct Lazy<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}
