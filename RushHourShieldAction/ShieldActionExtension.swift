//
//  ShieldActionExtension.swift
//  RushHourShieldAction
//
//  Created by Andrian on 01/06/26.
//

import Foundation
import ManagedSettings
import UserNotifications
import os

private let actionLog = OSLog(subsystem: "com.andrianangg.Traffic-Man.RushHourShieldAction", category: "ShieldAction")

class ShieldActionExtension: ShieldActionDelegate {
    override init() {
        super.init()
        os_log("RUSHHOUR_ACTION_INIT — ShieldActionExtension initialized", log: actionLog, type: .default)
    }

    private let appGroupId = "group.com.andrianangg.Traffic-Man"

    private func containerFile(_ name: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent(name)
    }

    private func loadEvents() -> [[String: Any]] {
        guard let url = containerFile("action_events.json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return arr
    }

    private func saveEvents(_ events: [[String: Any]]) {
        guard let url = containerFile("action_events.json"),
              let data = try? JSONSerialization.data(withJSONObject: events)
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        // .openParentalControlsApp (iOS 26.5) is the auto-open, but it's unreliable
        // (undocumented/buggy per Apple's own forums), so we ALSO queue a notification
        // as the dependable fallback the user taps. Schedule it FIRST (the async add can
        // be killed when this short-lived extension exits), THEN return the response.
        case .primaryButtonPressed:
            recordAction(token: application, action: "back")
            scheduleReturnNotification { self.respond(completionHandler) }
        case .secondaryButtonPressed:
            recordAction(token: application, action: "break")
            scheduleReasonPromptNotification(token: application) { self.respond(completionHandler) }
        @unknown default:
            completionHandler(.close)
        }
    }

    // the flaky auto-open; the notification we already queued is the dependable backup.
    private func respond(_ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        if #available(iOS 26.5, *) {
            completionHandler(.openParentalControlsApp)
        } else {
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
        var events = loadEvents()
        let tokenData = (try? JSONEncoder().encode(token)) ?? Data()
        let event: [String: Any] = [
            "id": UUID().uuidString,
            "tokenData": tokenData.base64EncodedString(),
            "occurredAt": Date().timeIntervalSince1970,
            "sourceKind": "shieldAction",
            "actionTaken": action
        ]
        events.append(event)
        saveEvents(events)
    }

    private func scheduleReasonPromptNotification(token: ApplicationToken, then: @escaping () -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "Tap to record your reason"
        content.body = "Come back to Rush Hour to log why you opened that app."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let tokenData = (try? JSONEncoder().encode(token)) ?? Data()
        content.userInfo = [
            "type": "jailbreakReason",
            "tokenData": tokenData.base64EncodedString()
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "rushhour.jailbreak.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { _ in then() }
    }

    private func scheduleReturnNotification(then: @escaping () -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "Back to Rush Hour"
        content.body = "Tap to return to your focus session."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "rushhour.return.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { _ in then() }
    }
}
