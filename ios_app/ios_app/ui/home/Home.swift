import SwiftUI
import UIKit

struct Item: Identifiable {
    let id: UUID = UUID()
    let name: String
}

struct HomeView: View {
    let items = [
        Item(name: "Foo"),
        Item(name: "Bar"),
    ]
    var body: some View {
        List(items) { hero in
            Text(hero.name)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
