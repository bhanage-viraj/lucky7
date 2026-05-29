import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let appGroupId = "group.com.andrianangg.Traffic-Man"
    private let pendingKey = "pendingJailbreakEvents"

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(displayName: application.localizedDisplayName,
                          bundleId: application.bundleIdentifier,
                          token: application.token)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(displayName: application.localizedDisplayName,
                          bundleId: application.bundleIdentifier,
                          token: application.token)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(displayName: webDomain.domain, bundleId: nil, token: nil)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(displayName: webDomain.domain, bundleId: nil, token: nil)
    }

    private func makeConfiguration(displayName: String?, bundleId: String?, token: ApplicationToken?) -> ShieldConfiguration {
        let name = displayName ?? "This app"
        let bundle = bundleId ?? ""

        recordShieldFire(displayName: name, bundleId: bundle, token: token)
        let count = countToday(bundleId: bundle, displayName: name)

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: UIColor(red: 24.0/255, green: 128.0/255, blue: 229.0/255, alpha: 1.0),
            icon: UIImage(named: "TicketStopSign"),
            title: ShieldConfiguration.Label(
                text: "\(name) has Ruined The Journey",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "\(count)x Today",
                color: .white
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "BACK TO SESSION",
                color: .white
            ),
            primaryButtonBackgroundColor: .black,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "BREAK IT",
                color: .white
            )
        )
    }

    private func recordShieldFire(displayName: String, bundleId: String, token: ApplicationToken?) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        var events = (defaults.array(forKey: pendingKey) as? [[String: Any]]) ?? []

        let now = Date().timeIntervalSince1970
        let recentWindow: TimeInterval = 2.0
        let isDuplicate = events.contains { evt in
            let evtBundle = evt["bundleId"] as? String ?? ""
            let evtName = evt["displayName"] as? String ?? ""
            let evtTime = evt["occurredAt"] as? TimeInterval ?? 0
            let matches = (!bundleId.isEmpty && evtBundle == bundleId) || (bundleId.isEmpty && evtName == displayName)
            let kindIsShieldFire = (evt["sourceKind"] as? String) == "shieldConfig"
            return matches && kindIsShieldFire && (now - evtTime) < recentWindow
        }
        if isDuplicate { return }

        let tokenData = token.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        let event: [String: Any] = [
            "id": UUID().uuidString,
            "displayName": displayName,
            "bundleId": bundleId,
            "tokenData": tokenData.base64EncodedString(),
            "occurredAt": now,
            "sourceKind": "shieldConfig",
            "actionTaken": NSNull()
        ]
        events.append(event)
        defaults.set(events, forKey: pendingKey)
    }

    private func countToday(bundleId: String, displayName: String) -> Int {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return 1 }
        let events = (defaults.array(forKey: pendingKey) as? [[String: Any]]) ?? []
        let todayStart = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        return events.filter { evt in
            let evtBundle = evt["bundleId"] as? String ?? ""
            let evtName = evt["displayName"] as? String ?? ""
            let evtTime = evt["occurredAt"] as? TimeInterval ?? 0
            let matches = (!bundleId.isEmpty && evtBundle == bundleId) || (bundleId.isEmpty && evtName == displayName)
            let kindIsShieldFire = (evt["sourceKind"] as? String) == "shieldConfig"
            return matches && kindIsShieldFire && evtTime >= todayStart
        }.count
    }
}
