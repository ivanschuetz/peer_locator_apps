import Foundation
import Combine

// This one is in its own class as there didn't see to be a service to meaningfully integrate it
// NOTE: failure reading validation data means that it's not necessarily our peer, but anyone using the app.
class BleValidationUIErrorDisplayer {
    private let bleValidationCancellable: AnyCancellable?

    init(uiNotifier: UINotifier, bleValidation: BleValidationDataReader) {
        bleValidationCancellable = bleValidation.errorReadingValidation.sink { error in
            // TODO how to handle this? if this happens consistently it's critical,
            // as this happens during the meeting, so it probably doesn't make sense to tell user to re-create the session.
            // maybe restart app/ble? what kind of errors can these be?

            uiNotifier.show(.error("Error reading periperal validation data: \(error)"))
        }
    }
}
