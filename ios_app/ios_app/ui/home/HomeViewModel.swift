import Foundation
import Combine
import SwiftUI

class HomeViewModel: ObservableObject {
    private let central = BleCentral()

    private var cancellable: AnyCancellable?

    @Published var labelValue: String = "Will show BLE status here"

    init() {
        cancellable = central.publisher
            .sink(receiveCompletion: { completion in }) { value in
                self.labelValue = value
        }
    }
}
