import Foundation
import UIKit
import Combine

enum AppEvent {
    case toFg
}

protocol AppEvents {
    var events: AnyPublisher<AppEvent, Never> { get }

}
class AppEventsImpl: AppEvents {
    private let eventsSubject = PassthroughSubject<AppEvent, Never>()
    lazy var events: AnyPublisher<AppEvent, Never> = eventsSubject.eraseToAnyPublisher()

    private var willEnterFgCancellable: AnyCancellable?

    init() {
        willEnterFgCancellable = NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification).sink { [weak self] _ in
            self?.eventsSubject.send(.toFg)
        }
    }
}
