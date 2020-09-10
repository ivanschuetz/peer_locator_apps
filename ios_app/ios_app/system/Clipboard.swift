import UIKit

protocol Clipboard {
    func putInClipboard(text: String)
    func getFromClipboard() -> String
}

class ClipboardImpl: Clipboard {
    func putInClipboard(text: String) {
        UIPasteboard.general.string = text
    }

    func getFromClipboard() -> String {
        UIPasteboard.general.string ?? ""
    }
}

class NoopClipboard: Clipboard {
    func getFromClipboard() -> String { "" }
    func putInClipboard(text: String) {}
}
