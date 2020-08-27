import Foundation
import Combine
import SwiftUI

class MeetingViewModel: ObservableObject {
    @Published var distance: String = ""

    private var discoveredCancellable: AnyCancellable?

    init(bleManager: BleManager) {
        discoveredCancellable = bleManager.discovered.sink { [weak self] discovered in
            self?.distance = "\(discovered.distance)m"
        }
    }
}

struct BleIdRow: Identifiable {
    let id: UUID
    let bleId: BleId
}
