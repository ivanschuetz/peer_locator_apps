import Foundation
import Combine

/**
 * Triggers an event when detected a valid device
 * This will probably not work well when supporting multiple peers.
 */
protocol ValidatedPeerEvent {
    var event: AnyPublisher<(), Never> { get }
}

class ValidatedBlePeerEvent: ValidatedPeerEvent {
    let event: AnyPublisher<(), Never>

    init(validDeviceService: DetectedBleDeviceFilterService) {
        // "Device came in max range (which is ble range)" = "meeting started"
        event = validDeviceService.device
            .map { $0.id } // discard distance
            // TODO review. For now we process only the first discovered valid device (should be fine?)
            // note also that if we didn't do this, i.e. sent an event on each validation it would be problematic
            // when we implement periodic validation. We're interested here specifically in "came in range",
            // not "determined that the device is valid".
            .removeDuplicates()
            .handleEvents(receiveOutput: { log.d("Discovered valid device, will send nearby discovery token: \($0)", .nearby) })
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

// Simulator: since validation runs through ble, we can't use it. So we fake a valid event when the session is ready.
// Ideally we'd make the validation work with multipeer service. No time right now.
class AlwaysValidPeerEvent: ValidatedPeerEvent {
    let event: AnyPublisher<(), Never>

    init(currentSession: CurrentSessionService) {
        event = currentSession.session
            .filter { sessionState in sessionState.isReady() }
            .map { _ in () }
            .handleEvents(receiveOutput: { log.d("Triggering a fake valid device event (simulator only)", .nearby) })
            .eraseToAnyPublisher()
    }
}
