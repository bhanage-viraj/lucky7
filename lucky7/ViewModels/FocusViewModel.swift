//
//  FocusViewModel.swift
//  lucky7
//
//  Created by Andrian on 31/05/26.
//

import Foundation
import Combine
#if os(iOS)
import FamilyControls
import ManagedSettings
import UserNotifications
import DeviceActivity
import ActivityKit
import SwiftUI
import UIKit

@MainActor
final class FocusViewModel: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    @Published private(set) var isEngaged = false
    @Published private(set) var isRunning = false   // focus actively running (false = paused, e.g. on a distraction)
    @Published private(set) var activeBreaks: [Distraction] = []
    @Published private(set) var now: Date = .now

    static let breakDuration: TimeInterval = 15 * 60
    static let appGroupId = "group.com.andrianangg.Traffic-Man"
    static let selectionDefaultsKey = "savedFamilyActivitySelection"
    // we can't read an app's URL scheme from its opaque token, so map the bundle
    // ids the shield-config extension reports to known schemes
    static let schemeByBundleId: [String: String] = [
        "com.burbn.instagram": "instagram://app",
        "com.google.ios.youtube": "youtube://",
        "com.zhiliaoapp.musically": "snssdk1233://",   // TikTok
        "com.atebits.Tweetie2": "twitter://",          // X / Twitter
        "com.facebook.Facebook": "fb://",
        "com.toyopagroup.picaboo": "snapchat://",
        "net.whatsapp.WhatsApp": "whatsapp://",
        "com.reddit.Reddit": "reddit://",
        "com.spotify.client": "spotify://",
        "jp.naver.line": "line://",                    // LINE
        "ph.telegra.Telegraph": "tg://",               // Telegram
        "com.hammerandchisel.discord": "discord://",
        "com.netflix.Netflix": "nflx://",
        "com.linkedin.LinkedIn": "linkedin://"      // LinkedIn
    ]

    private let store = ManagedSettingsStore(named: .rushHourFocus)
    private var tickTimer: Timer?

    init() {
        loadSelection()
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    var selectionSummary: String {
        let appCount = selection.applicationTokens.count
        let categoryCount = selection.categoryTokens.count
        let domainCount = selection.webDomainTokens.count
        var parts: [String] = []
        if appCount > 0 { parts.append("\(appCount) app\(appCount == 1 ? "" : "s")") }
        if categoryCount > 0 { parts.append("\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")") }
        if domainCount > 0 { parts.append("\(domainCount) site\(domainCount == 1 ? "" : "s")") }
        return parts.isEmpty ? "Nothing selected" : parts.joined(separator: ", ")
    }

    var selectionBinding: Binding<FamilyActivitySelection> {
        Binding(
            get: { self.selection },
            set: { self.selection = $0 }
        )
    }

    private let breakActivity = DeviceActivityName("rushhour.break")

    func engage() {
        guard hasSelection else { return }
        SharedJailbreakStore.startSession()
        saveSelectionForMonitor()
        applyShield()
        isEngaged = true
        isRunning = true
        startTicking()
    }

    func pause() {
        isRunning = false
    }

    // back from a distraction: reblock everything and resume focus
    func resume() {
        for distraction in activeBreaks {
            distraction.breakGrantedUntil = nil
            cancelBreakNotification(for: distraction)
        }
        activeBreaks.removeAll()
        applyShield()
        stopBreakMonitor()
        endBreakActivity()
        isRunning = true
    }

    func release() {
        store.clearAllSettings()
        isEngaged = false
        isRunning = false
        for distraction in activeBreaks {
            distraction.breakGrantedUntil = nil   // clear stale break state so nothing reads as still-active
            cancelBreakNotification(for: distraction)
        }
        activeBreaks.removeAll()
        stopBreakMonitor()
        endBreakActivity()
        stopTicking()
    }

    func grantBreak(for distraction: Distraction) {
        // only ONE app unlocked at a time — re-block any other break still active,
        // recording how long it was open so the stats stay correct.
        let others = activeBreaks.filter { $0.id != distraction.id }
        for other in others {
            other.breakGrantedUntil = nil
            if other.endTime == nil { other.endTime = .now }
            cancelBreakNotification(for: other)
        }
        activeBreaks.removeAll { $0.id != distraction.id }

        let until = Date().addingTimeInterval(Self.breakDuration)
        distraction.breakGrantedUntil = until
        if !activeBreaks.contains(where: { $0.id == distraction.id }) {
            activeBreaks.append(distraction)
        }
        applyShield()   // only this app is unblocked now; the previous one is re-blocked
        scheduleBreakNotification(for: distraction)
        startBreakMonitor()
        // no auto-redirect — the Live Activity shows the unlocked state and the user
        // opens the app themselves (that manual step is the friction we want).
        let appName = distraction.appDisplayName ?? distraction.appOpened
        startBreakActivity(appName: appName, until: until)
        // The island shows a string; resolve the real name (data-access) and backfill so the
        // island + the warning + the break-ended notification show it when the lookup works.
        if (distraction.appDisplayName ?? "").isEmpty {
            Task { @MainActor in
                guard let name = await resolveDisplayName(for: distraction), !name.isEmpty else { return }
                distraction.appDisplayName = name
                startBreakActivity(appName: name, until: until)   // updates the island in place
            }
        }
        isRunning = false   // they're distracted now — auto-pause the session
    }

    func endBreakEarly(for distraction: Distraction) {
        distraction.breakGrantedUntil = nil
        activeBreaks.removeAll { $0.id == distraction.id }
        applyShield()
        cancelBreakNotification(for: distraction)
        stopBreakMonitor()
        if activeBreaks.isEmpty { endBreakActivity() }
    }

    // schedules the 15-min interval; the monitor extension reblocks on intervalDidEnd
    private func startBreakMonitor() {
        saveSelectionForMonitor()
        let now = Date()
        let end = now.addingTimeInterval(Self.breakDuration)
        let cal = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: cal.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        try? DeviceActivityCenter().startMonitoring(breakActivity, during: schedule)
    }

    private func stopBreakMonitor() {
        DeviceActivityCenter().stopMonitoring([breakActivity])
    }

    private func saveSelectionForMonitor() {
        guard let url = SharedJailbreakStore.fileURL("monitor_selection.json"),
              let data = try? JSONEncoder().encode(selection) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Live Activity (the Dynamic Island break timer)

    private var liveActivity: Activity<BreakActivityAttributes>?

    private func startBreakActivity(appName: String, until endsAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let name = appName.isEmpty ? "Blocked App" : appName
        let state = BreakActivityAttributes.ContentState(
            startedAt: Date(),
            endsAt: endsAt,
            statusText: "\(name) unlocked"
        )
        // only one break is ever active — if the island is already up (switching
        // apps), update it to the new app instead of starting a second.
        if let activity = liveActivity {
            Task { await activity.update(ActivityContent(state: state, staleDate: endsAt)) }
            return
        }
        // start it compact, no expand — the in-app card already played the "expand
        // then shrink into the island" moment, so the island just shows quietly when
        // the user leaves (no re-expand).
        do {
            liveActivity = try Activity.request(
                attributes: BreakActivityAttributes(appName: name),
                content: ActivityContent(state: state, staleDate: endsAt),
                pushType: nil
            )
        } catch {
            // if it can't start we just go without the island timer
        }
    }

    private func endBreakActivity() {
        let current = liveActivity
        liveActivity = nil
        // Keep the app alive long enough to actually tear the Live Activity down — otherwise
        // ending the session can return before this async work runs and the island lingers.
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "endBreakActivity")
        Task {
            await current?.end(nil, dismissalPolicy: .immediate)
            for activity in Activity<BreakActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            UIApplication.shared.endBackgroundTask(bgTask)
        }
    }

    // scheme for a bundle id. table wins — it covers apps whose scheme is an
    // abbreviation (fb://, nflx://, tg://) or whose bundle id is an internal
    // codename (com.zhiliaoapp.musically = TikTok). for anything not listed, guess
    // from the last dot-component lowercased — works when brand == suffix == scheme
    // (com.linkedin.LinkedIn → linkedin://). guess can be wrong, but the app's
    // already unblocked so worst case is just no auto-bounce.
    private func scheme(for bundleId: String) -> String? {
        if let known = Self.schemeByBundleId[bundleId] { return known }
        guard let last = bundleId.split(separator: ".").last else { return nil }
        return "\(last.lowercased())://"
    }

    // exposed for the in-app "Test redirect" button — runs the exact same resolve
    // path as on-submit, opens the app, and returns what it did so the Stats
    // screen can show why it worked (or which step failed) without the shield flow.
    func redirectDiagnostic(for distraction: Distraction) async -> String {
        guard let bundleId = await resolveBundleId(for: distraction) else {
            return "couldn't resolve a bundle id (no data access?)"
        }
        let mapped = Self.schemeByBundleId[bundleId] != nil
        guard let scheme = scheme(for: bundleId), let url = URL(string: scheme) else {
            return "resolved \(bundleId) but couldn't form a scheme"
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return "opening \(bundleId) → \(scheme)\(mapped ? "" : " (guessed)")"
    }

    // open the specific app they broke. resolve its bundle id from the opaque
    // token via the data-access API, map to a scheme, and open it.
    private func routeBackToBlockedApp(for distraction: Distraction) {
        Task { @MainActor in
            guard let bundleId = await resolveBundleId(for: distraction),
                  let scheme = scheme(for: bundleId),
                  let url = URL(string: scheme) else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)   // let the shield lift first
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    // recover the blocked app's bundle id from its opaque token by matching it
    // against the installed-apps list — only readable when authorization is
    // .approvedWithDataAccess. Falls back to any bundle id we already stored.
    private func resolveBundleId(for distraction: Distraction) async -> String? {
        if let data = distraction.tokenData,
           let token = try? JSONDecoder().decode(ApplicationToken.self, from: data),
           let apps = try? await FamilyActivityData.shared.installedApplications,
           let match = apps.first(where: { $0.token == token }),
           let bid = match.bundleIdentifier {
            return bid
        }
        return distraction.appBundleId
    }

    // the visible app name from the opaque token (data-access). Label(token) covers
    // the in-app card, but the Dynamic Island, the "one break at a time" warning, and
    // the break-ended notification all need a plain string — this backfills it.
    // Resolve the real app name up front, while the app is still foregrounded on the reason
    // screen. If we only kick this off at break-grant time it can't finish — you immediately
    // leave to open the app and the lookup is suspended, so the Live Activity stays "Blocked App".
    func prefetchDisplayName(for distraction: Distraction) {
        guard (distraction.appDisplayName ?? "").isEmpty else { return }
        Task { @MainActor in
            if let name = await resolveDisplayName(for: distraction), !name.isEmpty {
                distraction.appDisplayName = name
            }
        }
    }

    private func resolveDisplayName(for distraction: Distraction) async -> String? {
        guard let data = distraction.tokenData,
              let token = try? JSONDecoder().decode(ApplicationToken.self, from: data),
              let apps = try? await FamilyActivityData.shared.installedApplications,
              let match = apps.first(where: { $0.token == token })
        else { return nil }
        return match.localizedDisplayName
    }

    func remainingSeconds(for distraction: Distraction) -> TimeInterval {
        guard let until = distraction.breakGrantedUntil else { return 0 }
        return max(0, until.timeIntervalSince(now))
    }

    func persistSelection() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId) else { return }
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: Self.selectionDefaultsKey)
        }
    }

    func loadSelection() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let data = defaults.data(forKey: Self.selectionDefaultsKey),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = decoded
    }

    private func applyShield() {
        let brokenTokens = Set(activeBreaks.compactMap { decodeToken($0.tokenData) })
        // A break whose token we can't decode is a CATEGORY break: iOS gives no per-app
        // token for a category, so we can't lift a single app out of it — we lift the
        // WHOLE category for the break, then re-block when it ends. Individual-app breaks
        // still lift surgically via brokenTokens above.
        let hasCategoryBreak = activeBreaks.contains { decodeToken($0.tokenData) == nil }

        let effective = selection.applicationTokens.subtracting(brokenTokens)
        store.shield.applications = effective.isEmpty ? nil : effective
        store.shield.applicationCategories = (selection.categoryTokens.isEmpty || hasCategoryBreak)
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil
            : selection.webDomainTokens
    }

    private func decodeToken(_ data: Data?) -> ApplicationToken? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }

    private func startTicking() {
        stopTicking()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        // Only do work (and publish `now`) while a break is actually active. Otherwise
        // this fired every second for the whole session and re-rendered the camera-heavy
        // recording screen for nothing — pure wasted work during recording.
        guard !activeBreaks.isEmpty else { return }
        now = .now
        let expired = activeBreaks.filter { d in
            guard let until = d.breakGrantedUntil else { return true }
            return until <= now
        }
        guard !expired.isEmpty else { return }
        for d in expired {
            d.breakGrantedUntil = nil
        }
        activeBreaks.removeAll { d in expired.contains(where: { $0.id == d.id }) }
        applyShield()
        if activeBreaks.isEmpty { endBreakActivity() }
    }

    private func scheduleBreakNotification(for distraction: Distraction) {
        let content = UNMutableNotificationContent()
        let appName = distraction.appDisplayName ?? distraction.appOpened
        content.title = appName.isEmpty ? "Break ended" : "\(appName) is locked again"
        content.body = "Your 15-minute break is over."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.breakDuration, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationId(for: distraction),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelBreakNotification(for distraction: Distraction) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationId(for: distraction)])
    }

    private func notificationId(for distraction: Distraction) -> String {
        "break.\(distraction.id.uuidString)"
    }
}

extension ManagedSettingsStore.Name {
    static let rushHourFocus = Self("rushhour.focus")
}
#endif
