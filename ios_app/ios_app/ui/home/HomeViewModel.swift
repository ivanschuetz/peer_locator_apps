import Foundation
import Combine
import SwiftUI

class HomeViewModel: ObservableObject {
    private let central: BleCentral

    @Published var labelValue: String = "Will show BLE status here"
    @Published var detectedDevices: [BleIdRow] = []

    private var statusCancellable: AnyCancellable?
    private var discoveredCancellable: AnyCancellable?

    init(central: BleCentral) {
        self.central = central

        statusCancellable = central.status
            .sink(receiveCompletion: { completion in }) { [weak self] status in
                self?.labelValue = "Bluetooth: \(status)"
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
