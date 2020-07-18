import Foundation
import Combine
import SwiftUI

class HomeViewModel: ObservableObject {
    private let central: BleCentral
    private let peripheral: BlePeripheral

    @Published var labelValue: String = ""
    @Published var myId: String = ""
    @Published var detectedDevices: [BleIdRow] = []

    @Published var radar: Radar = Radar(items: [])

    private let timer = Timer.TimerPublisher(interval: 2.0, runLoop: .main, mode: .default).autoconnect()

    private var timerCancellable: AnyCancellable?
    private var statusCancellable: AnyCancellable?
    private var myIdCancellable: AnyCancellable?
    private var discoveredCancellable: AnyCancellable?

    init(central: BleCentral, peripheral: BlePeripheral) {
        self.central = central
        self.peripheral = peripheral

        let radar1 = Radar(items: [
            RadarItem(id: UUID(uuidString: "00000000-0000-1000-8000-00805F9B3411")!, loc: CGPoint(x: 10, y: 200)),
            RadarItem(id: UUID(uuidString: "00000000-0000-1000-8000-00805F9B3412")!, loc: CGPoint(x: 100, y: 200)),
        ])

        let radar2 = Radar(items: [
            RadarItem(id: UUID(uuidString: "00000000-0000-1000-8000-00805F9B3411")!, loc: CGPoint(x: 100, y: 300)),
            RadarItem(id: UUID(uuidString: "00000000-0000-1000-8000-00805F9B3412")!, loc: CGPoint(x: 10, y: 100)),
            RadarItem(id: UUID(uuidString: "00000000-0000-1000-8000-00805F9B3413")!, loc: CGPoint(x: 300, y: 300))
        ])

        let radar3 = Radar(items: [
            RadarItem(id: UUID(uuidString: "00000000-0000-1000-8000-00805F9B3412")!, loc: CGPoint(x: 300, y: 400)),
            RadarItem(id: UUID(uuidString: "00000000-0000-1000-8000-00805F9B3413")!, loc: CGPoint(x: 200, y: 200))
        ])

        var counter = 0
        timerCancellable = timer.sink(receiveCompletion: { completion in }) { [weak self] date in
            let index = counter % 3
            let r: Radar = {
                switch index {
                case 0: return radar1
                case 1: return radar2
                case 2: return radar3
                default: fatalError("Wrong counter")
                }
            }()
            counter += 1
            print("Updating radar with: \(r)")
            self?.radar = r
        }

        statusCancellable = central.status
            .sink(receiveCompletion: { completion in }) { [weak self] status in
                self?.labelValue = "\(status)"
        }

        myIdCancellable = peripheral.readMyId.merge(with: central.writtenMyId)
            .sink(receiveCompletion: { completion in }) { [weak self] myId in
                self?.myId = myId.str()
        }

        discoveredCancellable = central.discovered
            .scan([], { acc, bleId in acc + [bleId] })
            .sink(receiveCompletion: { completion in }) { [weak self] ids in
                self?.detectedDevices = ids.map { BleIdRow(id: UUID(), bleId: $0) }
        }
    }
}

struct BleIdRow: Identifiable {
    let id: UUID
    let bleId: BleId
}
