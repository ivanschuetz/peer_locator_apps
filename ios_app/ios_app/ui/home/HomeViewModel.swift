import Foundation
import Combine
import SwiftUI

class HomeViewModel: ObservableObject {
    private let central: BleCentral
    private let peripheral: BlePeripheral

    @Published var labelValue: String = ""
    @Published var myId: String = ""
    @Published var detectedDevices: [BleIdRow] = []

    @Published var radarItems: [RadarItem] = []

    private let timer = Timer.TimerPublisher(interval: 2.0, runLoop: .main, mode: .default).autoconnect()

    private var radarCancellable: AnyCancellable?
    private var statusCancellable: AnyCancellable?
    private var myIdCancellable: AnyCancellable?
    private var discoveredCancellable: AnyCancellable?

    init(central: BleCentral, peripheral: BlePeripheral, radarService: RadarUIService,
         notificationPermission: NotificationPermission) {
        self.central = central
        self.peripheral = peripheral

        notificationPermission.request()

        statusCancellable = central.statusMsg
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

        radarCancellable = radarService.radar.sink { [weak self] radarItems in
            self?.radarItems = radarItems
        }
    }
}

struct BleIdRow: Identifiable {
    let id: UUID
    let bleId: BleId
}
