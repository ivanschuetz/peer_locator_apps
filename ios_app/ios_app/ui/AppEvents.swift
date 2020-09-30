import Foundation
import UIKit
import Combine

enum AppEvent {
    case toFg, didLaunch, none
}

protocol AppEvents {
    var events: AnyPublisher<AppEvent, Never> { get }

}
class AppEventsImpl: AppEvents {
    private let eventsSubject = CurrentValueSubject<AppEvent, Never>(.none)
    lazy var events: AnyPublisher<AppEvent, Never> = eventsSubject
        .handleEvents(receiveOutput: { log.d("App event: \($0)", .ui) })
        .eraseToAnyPublisher()

    private var willEnterFgCancellable: AnyCancellable?
    private var didLaunchCancellable: AnyCancellable?

    init() {
        willEnterFgCancellable = NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification).sink { [weak self] _ in
            self?.eventsSubject.send(.toFg)
        }

        didLaunchCancellable = NotificationCenter.default.publisher(
            for: UIApplication.didFinishLaunchingNotification).sink { [weak self] _ in
            self?.eventsSubject.send(.didLaunch)
        }
    }

    // TODO is this needed? these singleton dependencies are destroyed only when the app is destroyed
    // so removing observer seems unnecessary
    deinit {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        notificationCenter.removeObserver(
            self,
            name: UIApplication.didFinishLaunchingNotification,
            object: nil
        )
    }
}

class NoopAppEvents: AppEvents {
    let events: AnyPublisher<AppEvent, Never> = Empty().eraseToAnyPublisher()
}
