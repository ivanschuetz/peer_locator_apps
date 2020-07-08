import Foundation
import Combine
import SwiftUI

class HomeViewModel: ObservableObject {
    private let central: BleCentral
    private let peripheral: BlePeripheral

    @Published var labelValue: String = ""
    @Published var myId: String = ""
    @Published var detectedDevices: [BleIdRow] = []

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

        myIdCancellable = peripheral.myId
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
