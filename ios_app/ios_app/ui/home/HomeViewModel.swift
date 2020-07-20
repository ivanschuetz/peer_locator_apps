import Foundation
import Combine
import SwiftUI

class HomeViewModel: ObservableObject {
    private let central: BleCentral
    private let peripheral: BlePeripheral

    @Published var labelValue: String = ""
    @Published var myId: String = ""
    @Published var detectedDevices: [BleIdRow] = []

    @Published var radar: Dictionary<BleId, RadarItem> = Dictionary()

    @Published var radarViewItems: [RadarForViewItem] = []

    private let timer = Timer.TimerPublisher(interval: 2.0, runLoop: .main, mode: .default).autoconnect()

    private var radarCancellable: AnyCancellable?
    private var statusCancellable: AnyCancellable?
    private var myIdCancellable: AnyCancellable?
    private var discoveredCancellable: AnyCancellable?

    init(central: BleCentral, peripheral: BlePeripheral) {
        self.central = central
        self.peripheral = peripheral

        statusCancellable = central.status
            .sink(receiveCompletion: { completion in }) { [weak self] status in
                self?.labelValue = "\(status)"
        }

        myIdCancellable = peripheral.readMyId.merge(with: central.writtenMyId)
            .sink(receiveCompletion: { completion in }) { [weak self] myId in
                self?.myId = myId.str()
        }

        discoveredCancellable = central.discovered
            .removeDuplicates(by: { t1, t2 in
                t1.0.data == t2.0.data
            })
            .scan([], { acc, bleId in acc + [bleId.0] })
            .sink(receiveCompletion: { completion in }) { [weak self] ids in
                self?.detectedDevices = ids.map { BleIdRow(id: UUID(), bleId: $0) }
            }

        let radar = central.discovered
            .scan(Dictionary<BleId, RadarItem>(), { acc, bleId in
                var dict: Dictionary<BleId, RadarItem> = acc
                dict[bleId.0] = RadarItem(id: bleId.0, loc: CGPoint(x: bleId.1, y: bleId.1), distance: Float(bleId.1))
                return dict
            })

        radarCancellable = radar.sink { [weak self] radarItems in
            let viewItems = radarItems.map { $0.value.toRadarForViewItem() }
            print("received radarItems: \(radarItems), mapped to: \(viewItems)")
            self?.radarViewItems = viewItems
        }
    }
}

struct BleIdRow: Identifiable {
    let id: UUID
    let bleId: BleId
}

struct RadarItem: Identifiable, Hashable {
    var id: BleId
    let loc: CGPoint
    let distance: Float

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

//let maxRadius: CGFloat = 6000
let maxRadius: CGFloat = 120 // 1m 20cm (for easier testing)
let viewRadius: CGFloat = 150 // TODO: ensure same as in RadarView

extension RadarItem {
    func toRadarForViewItem() -> RadarForViewItem {
        let multiplier = viewRadius / maxRadius

        let screenLoc = CGPoint(x: loc.x * multiplier + viewRadius, y: -loc.y * multiplier + viewRadius)

        // Temporary: as we're using distance as coordinates
        let distance = String(format: "%.0f", loc.x)
        let screenDistance = String(format: "%.0f", screenLoc.x)

        return RadarForViewItem(
            id: id,
            loc: screenLoc,
            text: "\(distance)->\(screenDistance)"
        )
    }
}

struct Radar {
    let items: Set<RadarItem>
}
