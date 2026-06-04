//
//  NotificationPermission.swift
//  lucky7
//
//  Created by Andrian on 29/05/26.
//

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

    // The shield → app return relies on a notification fallback, so the block
    // feature needs this granted. True when the user has DENIED it — iOS won't
    // re-show the prompt, so the app must nudge them to Settings.
    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }
}
