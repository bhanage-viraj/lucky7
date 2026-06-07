//
//  SharedJailbreakStore.swift
//  lucky7
//
//  Created by Andrian on 31/05/26.
//

import Foundation

struct PendingJailbreakEvent: Identifiable {
    let id: String
    let displayName: String?
    let bundleId: String?
    let tokenData: Data?
    let occurredAt: Date
    let sourceKind: String
    let actionTaken: String?
}

// Each writer gets its own file so the app and the two extensions never
// overwrite each other's events. The app reads all of them.
enum SharedJailbreakStore {
    static let appGroupId = "group.com.andrianangg.Traffic-Man"

    static func fileURL(_ name: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent(name)
    }

    static var configFileURL: URL? { fileURL("config_events.json") }
    static var actionFileURL: URL? { fileURL("action_events.json") }
    static var sessionFileURL: URL? { fileURL("session.json") }
    static var openCountFileURL: URL? { fileURL("open_count.json") }

    static func loadArray(_ url: URL?) -> [[String: Any]] {
        guard let url, let data = try? Data(contentsOf: url),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return arr
    }

    static func parse(_ dict: [String: Any]) -> PendingJailbreakEvent? {
        guard let id = dict["id"] as? String,
              let occurredAtSeconds = dict["occurredAt"] as? TimeInterval,
              let sourceKind = dict["sourceKind"] as? String
        else { return nil }
        let displayName = (dict["displayName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let bundleId = (dict["bundleId"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let tokenData = Data(base64Encoded: dict["tokenData"] as? String ?? "")
        return PendingJailbreakEvent(
            id: id,
            displayName: displayName,
            bundleId: bundleId,
            tokenData: tokenData,
            occurredAt: Date(timeIntervalSince1970: occurredAtSeconds),
            sourceKind: sourceKind,
            actionTaken: dict["actionTaken"] as? String
        )
    }

    // tracks the last break we've already shown a prompt for, so we don't
    // re-prompt the same one (without wiping the action events the count needs)
    static var lastPromptedBreakAt: TimeInterval {
        get { UserDefaults.standard.double(forKey: "lastPromptedBreakAt") }
        set { UserDefaults.standard.set(newValue, forKey: "lastPromptedBreakAt") }
    }

    static func nextUnhandledBreak() -> (action: PendingJailbreakEvent, config: PendingJailbreakEvent?)? {
        let handledUntil = lastPromptedBreakAt
        let actions = loadArray(actionFileURL).compactMap(parse)
        let configs = loadArray(configFileURL).compactMap(parse).sorted { $0.occurredAt > $1.occurredAt }

        guard let breakAction = actions
            .filter({ $0.actionTaken == "break" && $0.occurredAt.timeIntervalSince1970 > handledUntil })
            .sorted(by: { $0.occurredAt > $1.occurredAt })
            .first
        else { return nil }

        let matchingConfig = configs.first(where: { cfg in
            guard let c = cfg.tokenData, let b = breakAction.tokenData else { return false }
            return c == b
        }) ?? configs.first

        return (breakAction, matchingConfig)
    }

    static func markBreakHandled(_ occurredAt: Date) {
        lastPromptedBreakAt = occurredAt.timeIntervalSince1970
    }

    static func removeAll() {
        [configFileURL, actionFileURL, sessionFileURL, openCountFileURL, configSharedURL].forEach { url in
            if let url { try? FileManager.default.removeItem(at: url) }
        }
    }

    // the shield-config extension writes this file on every open of a blocked
    // app: { lastAppName, lastBundleId, counts: [name:Int] }. A file is the
    // channel that actually reaches the app cross-process; UserDefaults is a
    // best-effort fallback.
    static var configSharedURL: URL? { fileURL("config_shared.json") }

    // diagnostic — the config ext increments this each render; if it climbs in
    // the app too, the config ext's UserDefaults writes DO reach us cross-process
    // cross-process App Group UserDefaults is cached by cfprefsd, so a plain read
    // returns STALE values that the shield extensions wrote. Force a sync first
    // (the pattern the kingstinct device-activity library uses), then read fresh.
    private static func sharedDefaults() -> UserDefaults? {
        CFPreferencesAppSynchronize(appGroupId as CFString)
        return UserDefaults(suiteName: appGroupId)
    }

    static func configTick() -> Int {
        sharedDefaults()?.integer(forKey: "configTick") ?? 0
    }

    // [app name: times opened this session]
    static func openCounts() -> [String: Int] {
        (sharedDefaults()?.dictionary(forKey: "openCountsByApp") as? [String: Int]) ?? [:]
    }

    // most-recently-shielded app — the action extension only has an opaque token,
    // so the app reads these to label a break and to know which app to route to
    static func lastShieldedAppName() -> String? {
        sharedDefaults()?.string(forKey: "lastShieldedAppName")
    }

    static func lastShieldedBundleId() -> String? {
        sharedDefaults()?.string(forKey: "lastShieldedBundleId")
    }

    static func openCount() -> Int {
        openCounts().values.reduce(0, +)
    }

    static func startSession() {
        removeAll()   // also deletes config_shared.json so counts/last-app reset
        lastPromptedBreakAt = 0
        // clear the fallback defaults too
        if let defaults = UserDefaults(suiteName: appGroupId) {
            defaults.removeObject(forKey: "openCountsByApp")
            defaults.removeObject(forKey: "lastOpenByApp")
            defaults.removeObject(forKey: "lastShieldedAppName")
            defaults.removeObject(forKey: "lastShieldedBundleId")
            defaults.removeObject(forKey: "configTick")
            // The shield-config ext can't see our deletions (its own cfprefs cache masks
            // them), but it CAN read a key only WE write. Stamp the session start; the ext
            // compares it to its own last-seen stamp and resets its count itself.
            defaults.set(Date().timeIntervalSince1970, forKey: "sessionStartedAt")
            defaults.set(true, forKey: "sessionActive")   // monitor ext checks this before re-blocking
            CFPreferencesAppSynchronize(appGroupId as CFString)   // flush so the shield ext reads the new stamp
        }
        let session: [String: Any] = ["startedAt": Date().timeIntervalSince1970]
        if let url = sessionFileURL, let data = try? JSONSerialization.data(withJSONObject: session) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // closing the app / ending the session: mark it over so the monitor extension stops
    // re-blocking on intervalDidEnd and the next launch knows any lingering shield is stale.
    static func endSession() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set(false, forKey: "sessionActive")
        CFPreferencesAppSynchronize(appGroupId as CFString)
        if let url = sessionFileURL { try? FileManager.default.removeItem(at: url) }
    }
}
