//
//  DeviceActivityMonitorExtension.swift
//  RushHourJailBreakMonitor
//
//  Created by Andrian on 01/06/26.
//

import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let appGroupId = "group.com.andrianangg.Traffic-Man"

    private func containerFile(_ name: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent(name)
    }

    private func loadSelection() -> FamilyActivitySelection? {
        guard let url = containerFile("monitor_selection.json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    // break is over → put the shield back on everything
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let selection = loadSelection() else { return }
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("rushhour.focus"))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }
}
