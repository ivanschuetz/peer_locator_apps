import Foundation
import Combine
import SwiftUI

class HomeViewModel: ObservableObject {
    private let central: BleCentral

    @Published var labelValue: String = "Will show BLE status here"

    private var cancellable: AnyCancellable?

    init(central: BleCentral) {
        self.central = central

        cancellable = central.publisher
            .sink(receiveCompletion: { completion in }) { value in
                self.labelValue = "Bluetooth: \(value)"
        }
    }
}
