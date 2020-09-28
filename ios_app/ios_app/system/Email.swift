import UIKit

protocol Email {
    func openEmail(address: String, subject: String)
}

class EmailImpl: Email {
    func openEmail(address: String, subject: String) {
        let sanitized = subject.replacingOccurrences(of: " ", with: "%20")
        guard let url = URL(string: "mailto:\(address)?subject=\(sanitized)") else {
            log.e("Couldn't create email URL for: \(address), \(subject)", .ui)
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

class NoopEmail: Email {
    func openEmail(address: String, subject: String) {}
}
