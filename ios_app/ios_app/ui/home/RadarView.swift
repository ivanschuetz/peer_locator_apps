import Foundation
import SwiftUI

struct RadarView: View {

    @ObservedObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }

    @State var items: [RadarForViewItem] = []

    var body: some View {
        GeometryReader { geometry in
            VStack {
                ZStack {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    ForEach(items, id: \.id) { item in
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .position(
                                x: item.loc.x,
                                y: item.loc.y
                            )
                    }
                }.frame(width: 300, height: 400).onReceive(viewModel.$radarViewItems) { items in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.items = items
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct RadarForViewItem: Identifiable {
    var id: BleId
    let loc: CGPoint
}

struct RadarForView {
    let items: [RadarForViewItem]
}
