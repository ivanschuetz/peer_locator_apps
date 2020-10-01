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
            for: UIApplication.didFinishLaunchingNotification).sink { [weak self] par in
                // Note: we don't access central/peripheral restoration identifiers here
                // (described in https://apple.co/3l09b1i section "Reinstantiate Your Central and Peripheral Managers")
                // as we've only one identifier respectively and we want them to be always active
                // (note, though, that the later will not necessarily be always the case: we wanted to activate ble
                // on-demand only. For now not doing this, to simplify things)
                log.d("Did finish launching, par: \(par)", .ui)
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
