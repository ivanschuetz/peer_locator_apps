import UserNotifications

protocol NotificationPermission {
    func request()
}

class NotificationPermissionImpl: NotificationPermission {

    func request() {
        UNUserNotificationCenter
            .current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            if let error = error {
                log.e("Error requesting permission: \(error)", .notifications)
            } else {
                log.i("Notification permission granted: \(granted)", .notifications)
            }
        }
    }
}
