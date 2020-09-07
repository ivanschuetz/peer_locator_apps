import Foundation
import UIKit

protocol BleRestarterWhenAppComesToFg {}

class BleRestarterWhenAppComesToFgImpl: BleRestarterWhenAppComesToFg {
    private let bleCentral: BleCentral

    init(bleCentral: BleCentral) {
        self.bleCentral = bleCentral

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillEnterForegroundNotification(_:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc func applicationWillEnterForegroundNotification(
        _ notification: Notification
    ) {
        // Workaround: if user toggles ble while app is in bg,
        // scanning fails when coming to fg, so restart.
        bleCentral.requestStart()
    }

    deinit {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
}
