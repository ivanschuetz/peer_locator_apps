import UserNotifications

class NotificationsDelegate: NSObject, UNUserNotificationCenterDelegate {

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions)
        -> Void) {

        // Used to display notification while app is in FG
        completionHandler([
            .badge,
            .alert,
            .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping ()
        -> Void) {

//        let identifierStr = response.notification.request.identifier
//        guard let identifier = NotificationId(rawValue: identifierStr) else {
//            log.d("Selected notification with unknown id: \(identifierStr)")
//            return
//        }
    }
}
