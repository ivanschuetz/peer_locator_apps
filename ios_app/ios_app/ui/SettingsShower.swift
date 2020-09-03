import Foundation
import Combine

protocol SettingsShower {
    var showing: AnyPublisher<Bool, Never> { get }

    func show()
    func hide()
}

class SettingsShowerImpl: SettingsShower {
    private let showSubject = PassthroughSubject<Bool, Never>()
    lazy var showing: AnyPublisher<Bool, Never> = showSubject.eraseToAnyPublisher()

    func show() {
        showSubject.send(true)
    }

    func hide() {
        showSubject.send(false)
    }
}
