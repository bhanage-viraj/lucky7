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

enum SharedJailbreakStore {
    static let appGroupId = "group.com.andrianangg.Traffic-Man"
    static let pendingKey = "pendingJailbreakEvents"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func readEvents() -> [PendingJailbreakEvent] {
        guard let defaults else { return [] }
        let raw = (defaults.array(forKey: pendingKey) as? [[String: Any]]) ?? []
        return raw.compactMap { dict -> PendingJailbreakEvent? in
            guard let id = dict["id"] as? String,
                  let occurredAtSeconds = dict["occurredAt"] as? TimeInterval,
                  let sourceKind = dict["sourceKind"] as? String
            else { return nil }

            let displayName: String? = (dict["displayName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let bundleId: String? = (dict["bundleId"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let tokenBase64 = dict["tokenData"] as? String ?? ""
            let tokenData = Data(base64Encoded: tokenBase64)
            let actionTaken: String? = dict["actionTaken"] as? String

            return PendingJailbreakEvent(
                id: id,
                displayName: displayName,
                bundleId: bundleId,
                tokenData: tokenData,
                occurredAt: Date(timeIntervalSince1970: occurredAtSeconds),
                sourceKind: sourceKind,
                actionTaken: actionTaken
            )
        }
    }

    /// Returns the most recent un-handled "break" event paired with its matching shieldConfig event (which has the display name).
    static func nextUnhandledBreak() -> (action: PendingJailbreakEvent, config: PendingJailbreakEvent?)? {
        let all = readEvents()
        guard let breakAction = all
            .filter({ $0.sourceKind == "shieldAction" && $0.actionTaken == "break" })
            .sorted(by: { $0.occurredAt > $1.occurredAt })
            .first
        else { return nil }

        let matchingConfig = all
            .filter { $0.sourceKind == "shieldConfig" }
            .filter { evt in
                guard let evtToken = evt.tokenData, let breakToken = breakAction.tokenData else {
                    return false
                }
                return evtToken == breakToken
            }
            .sorted(by: { $0.occurredAt > $1.occurredAt })
            .first

        return (breakAction, matchingConfig)
    }

    static func removeEvents(matching tokenData: Data?) {
        guard let defaults, let tokenData else { return }
        let tokenBase64 = tokenData.base64EncodedString()
        let raw = (defaults.array(forKey: pendingKey) as? [[String: Any]]) ?? []
        let filtered = raw.filter { dict in
            (dict["tokenData"] as? String) != tokenBase64
        }
        defaults.set(filtered, forKey: pendingKey)
    }

    static func removeAll() {
        defaults?.removeObject(forKey: pendingKey)
    }
}
