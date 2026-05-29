import ManagedSettings
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {
    private let appGroupId = "group.com.andrianangg.Traffic-Man"
    private let pendingKey = "pendingJailbreakEvents"

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            recordAction(token: application, action: "back")
            completionHandler(.close)
        case .secondaryButtonPressed:
            recordAction(token: application, action: "break")
            scheduleReasonPromptNotification(token: application)
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    private func recordAction(token: ApplicationToken, action: String) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        var events = (defaults.array(forKey: pendingKey) as? [[String: Any]]) ?? []
        let tokenData = (try? JSONEncoder().encode(token)) ?? Data()
        let event: [String: Any] = [
            "id": UUID().uuidString,
            "displayName": NSNull(),
            "bundleId": NSNull(),
            "tokenData": tokenData.base64EncodedString(),
            "occurredAt": Date().timeIntervalSince1970,
            "sourceKind": "shieldAction",
            "actionTaken": action
        ]
        events.append(event)
        defaults.set(events, forKey: pendingKey)
    }

    private func scheduleReasonPromptNotification(token: ApplicationToken) {
        let content = UNMutableNotificationContent()
        content.title = "Tell Rush Hour your reason"
        content.body = "Tap to record why you opened that app."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let tokenData = (try? JSONEncoder().encode(token)) ?? Data()
        content.userInfo = [
            "type": "jailbreakReason",
            "tokenData": tokenData.base64EncodedString()
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "rushhour.jailbreak.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
