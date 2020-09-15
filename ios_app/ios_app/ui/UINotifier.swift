import Foundation

enum UINotification {
    case success(_ message: String)
    case error(_ message: String)
}

protocol UINotifier {
    func show(_ notification: UINotification)
}
