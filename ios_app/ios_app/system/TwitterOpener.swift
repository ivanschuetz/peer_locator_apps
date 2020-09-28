import SwiftUI

protocol TwitterOpener {
    func open(userName: String) -> Bool
}

class TwitterOpenerImpl: TwitterOpener {
    func open(userName: String) -> Bool {
        let appURL = NSURL(string: "twitter:///user?screen_name=\(userName)")!
        let application = UIApplication.shared
        if application.canOpenURL(appURL as URL) {
            application.open(appURL as URL)
            return true
        } else {
            return false
        }
    }
}

class NoopTwitterOpener: TwitterOpener {
    func open(userName: String) -> Bool {
        return true
    }
}
