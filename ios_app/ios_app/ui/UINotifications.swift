import Foundation
import UIKit
import SwiftEntryKit

enum UINotification {
    case success(_ message: String)
    case error(_ message: String)
}

protocol UINotifier {
    func show(_ notification: UINotification)
}

class UINotifierImpl: UINotifier {
    func show(_ notification: UINotification) {
        let data: (message: String, color: UIColor) = {
            switch notification {
            case let .error(message):
                return (message, .red)
            case let .success(message):
                return (message, .systemGreen)
            }
        }()
        SwiftEntryKit.display(entry: createView(title: "", message: data.message),
                              using: attributes(backgroundColor: data.color))
    }

    private func createView(title: String, message: String) -> UIView {
        let title = EKProperty.LabelContent(
            text: title,
            style: .init(font: .systemFont(ofSize: 18), color: .white)
        )
        let description = EKProperty.LabelContent(
            text: message,
            style: .init(font: .systemFont(ofSize: 18), color: .white)
        )
        let simpleMessage = EKSimpleMessage(image: nil, title: title, description: description)
        let notificationMessage = EKNotificationMessage(simpleMessage: simpleMessage)

        return EKNotificationMessageView(with: notificationMessage)
    }

    private func attributes(backgroundColor: UIColor) -> EKAttributes {
        var attributes = EKAttributes.topFloat
        attributes.precedence = .enqueue(priority: .normal)
        attributes.windowLevel = .alerts

        attributes.entranceAnimation = .translation
        attributes.exitAnimation = .translation

        attributes.displayDuration = 4
        attributes.entryBackground = .color(color: EKColor(backgroundColor))
        attributes.positionConstraints.verticalOffset = 0
        return attributes
    }
}

