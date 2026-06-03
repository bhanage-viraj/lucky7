//
//  ShieldConfigurationExtension.swift
//  RushHourShieldConfig
//
//  Created by Andrian on 01/06/26.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// This extension renders the shield and iOS calls it on every open of a blocked
// app. It shares state with the main app through a FILE in the app group (the
// same channel the action extension uses successfully) — UserDefaults writes
// from here don't reliably reach the app process. We stash the last-shielded
// app's name + bundle id and the per-app open counts there.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let appGroupId = "group.com.andrianangg.Traffic-Man"

    private func containerFile(_ name: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent(name)
    }

    // a render = the user just opened THIS blocked app. record its name + bundle
    // id and bump its per-app count in shared defaults (this ext can't write
    // files, but UserDefaults persists for it). debounced ~2s. returns count.
    // also bumps a "configTick" so the app can tell if our writes reach it.
    private func recordOpen(name: String?, bundleId: String?) -> Int {
        CFPreferencesAppSynchronize(appGroupId as CFString)   // read/write the live store, not a cached copy
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return 1 }
        defaults.set(defaults.integer(forKey: "configTick") + 1, forKey: "configTick")
        if let name { defaults.set(name, forKey: "lastShieldedAppName") }
        if let bundleId { defaults.set(bundleId, forKey: "lastShieldedBundleId") }

        let key = name ?? "Unknown"
        let now = Date().timeIntervalSince1970
        var counts = (defaults.dictionary(forKey: "openCountsByApp") as? [String: Int]) ?? [:]
        var lasts = (defaults.dictionary(forKey: "lastOpenByApp") as? [String: Double]) ?? [:]
        var count = counts[key] ?? 0
        if now - (lasts[key] ?? 0) > 0.5 {   // small debounce: collapse one open's rapid double-render, but count real re-opens
            count += 1
            counts[key] = count
            lasts[key] = now
            defaults.set(counts, forKey: "openCountsByApp")
            defaults.set(lasts, forKey: "lastOpenByApp")
        }
        // flush our writes out to the shared cfprefsd store so the app can read them
        CFPreferencesAppSynchronize(appGroupId as CFString)
        return max(count, 1)
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName, bundleId: application.bundleIdentifier)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName, bundleId: application.bundleIdentifier)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain, bundleId: nil)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain, bundleId: nil)
    }

    private func makeConfiguration(name: String?, bundleId: String?) -> ShieldConfiguration {
        let appName = name ?? "This app"
        let count = recordOpen(name: name, bundleId: bundleId)
        let timesText = count == 1 ? "1 time today" : "\(count) times today"

        let blue = UIColor(red: 24.0/255, green: 128.0/255, blue: 229.0/255, alpha: 1.0)
        // white page in light mode, black in dark mode
        let bgColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .black : .white
        }
        // body text: black in light mode, white in dark mode
        let fontColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : .black
        }
        // BACK button flips: black pill in light, white pill in dark
        let backButtonBg = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : .black
        }
        let backButtonText = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .black : .white
        }

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: bgColor,
            icon: UIImage(named: "ShieldFigure"),
            title: ShieldConfiguration.Label(text: "Warning for Distraction!", color: fontColor),
            subtitle: ShieldConfiguration.Label(
                text: "Wrong turn! This app is a distraction pit stop. Keep your eyes on the road ahead.\n\n\(appName) has ruined the journey\n\(timesText)",
                color: fontColor
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "BACK TO SESSION", color: backButtonText),
            primaryButtonBackgroundColor: backButtonBg,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "BREAK IT", color: blue)
        )
    }
}
