import Foundation
import UIKit

protocol Voice {
    func say(_ text: String)
}

class VoiceImpl: Voice {
    func say(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
        log.v("Voice is saying: \(text)", .voice)
    }
}
