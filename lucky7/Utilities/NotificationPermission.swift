import Foundation
import UserNotifications

@MainActor
enum NotificationPermission {
    static func requestIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
    }
}
