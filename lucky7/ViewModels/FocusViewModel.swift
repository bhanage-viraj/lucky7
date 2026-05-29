import Foundation
import Combine
#if os(iOS)
import FamilyControls
import ManagedSettings
import UserNotifications

@MainActor
final class FocusViewModel: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    @Published private(set) var isEngaged = false
    @Published private(set) var activeBreaks: [Distraction] = []
    @Published private(set) var now: Date = .now

    static let breakDuration: TimeInterval = 15 * 60

    private let store = ManagedSettingsStore(named: .rushHourFocus)
    private var tickTimer: Timer?

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

    func engage() {
        guard hasSelection else { return }
        applyShield()
        isEngaged = true
        startTicking()
    }

    func release() {
        store.clearAllSettings()
        isEngaged = false
        for distraction in activeBreaks {
            cancelBreakNotification(for: distraction)
        }
        activeBreaks.removeAll()
        stopTicking()
    }

    func grantBreak(for distraction: Distraction) {
        distraction.breakGrantedUntil = .now.addingTimeInterval(Self.breakDuration)
        if !activeBreaks.contains(where: { $0.id == distraction.id }) {
            activeBreaks.append(distraction)
        }
        applyShield()
        scheduleBreakNotification(for: distraction)
    }

    func endBreakEarly(for distraction: Distraction) {
        distraction.breakGrantedUntil = nil
        activeBreaks.removeAll { $0.id == distraction.id }
        applyShield()
        cancelBreakNotification(for: distraction)
    }

    func remainingSeconds(for distraction: Distraction) -> TimeInterval {
        guard let until = distraction.breakGrantedUntil else { return 0 }
        return max(0, until.timeIntervalSince(now))
    }

    private func applyShield() {
        let brokenTokens = Set(activeBreaks.compactMap { decodeToken($0.tokenData) })
        let effective = selection.applicationTokens.subtracting(brokenTokens)
        store.shield.applications = effective.isEmpty ? nil : effective
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
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
