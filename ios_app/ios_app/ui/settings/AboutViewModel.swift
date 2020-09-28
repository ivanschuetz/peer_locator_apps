import SwiftUI

class AboutViewModel: ObservableObject {
    private static let twitterUserName = "peerfinder1"

    @Published var presentingSafariView = false
    @Published var safariViewUrl: URL = URL(string: "https://twitter.com/\(twitterUserName)")!

    private let email: Email
    private let twitterOpener: TwitterOpener

    init(email: Email, twitterOpener: TwitterOpener) {
        self.email = email
        self.twitterOpener = twitterOpener
    }

    func onTwitterTap() {
        if !twitterOpener.open(userName: Self.twitterUserName) {
            presentingSafariView = true
        }
    }

    func onContactTap() {
        email.openEmail(address: "contact@peerfinder.xyz", subject: "iOS app")
    }

    deinit {
        log.d("View model deinit", .ui)
    }
}
