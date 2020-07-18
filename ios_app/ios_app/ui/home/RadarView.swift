import Foundation
import SwiftUI

struct RadarView: View {

    @State var position: CGFloat = 10
    @State var radar: Radar = Radar(items: [
        RadarItem(id: 1, loc: CGPoint(x: 10, y: 200)),
        RadarItem(id: 2, loc: CGPoint(x: 100, y: 200)),
    ])

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
                }.frame(width: geometry.size.width, height: 400)

                Button("Animate") {
                    withAnimation(.easeInOut(duration: 2)) {
                        radar = Radar(items: [
                            RadarItem(id: 1, loc: CGPoint(x: 110, y: 200)),
                            RadarItem(id: 2, loc: CGPoint(x: 200, y: 200)),
                            RadarItem(id: 3, loc: CGPoint(x: 300, y: 300))
                        ])
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct RadarView_Previews: PreviewProvider {
    static var previews: some View {
        RadarView()
    }
}

struct RadarItem: Identifiable {
    var id: Int

    let loc: CGPoint
}

struct Radar {
    let items: [RadarItem]
}
