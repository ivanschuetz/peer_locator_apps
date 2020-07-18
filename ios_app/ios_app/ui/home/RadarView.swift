import Foundation
import SwiftUI

struct RadarView: View {

    @ObservedObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }

    @State var radar: Radar = Radar(items: [])

    var body: some View {
        GeometryReader { geometry in
            VStack {
                ZStack {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    ForEach(radar.items, id: \.id) { item in
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .position(
                                x: item.loc.x,
                                y: item.loc.y
                            )
                    }
                }.frame(width: geometry.size.width, height: 400).onReceive(viewModel.$radar) { radar in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.radar = radar
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct RadarItem: Identifiable {
    var id: UUID
    let loc: CGPoint
}

struct Radar {
    let items: [RadarItem]
}
