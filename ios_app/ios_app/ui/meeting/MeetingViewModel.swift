import Foundation
import Combine
import SwiftUI

class MeetingViewModel: ObservableObject {
    @Published var distance: String = ""

    private var discoveredCancellable: AnyCancellable?

    init(peerService: PeerService) {
        discoveredCancellable = peerService.peer.sink { [weak self] peer in
            // TODO handle optional
            self?.distance = "\(peer.dist)m"
        }
    }
}

struct BleIdRow: Identifiable {
    let id: UUID
    let bleId: BleId
}
