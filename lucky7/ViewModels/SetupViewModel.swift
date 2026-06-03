//
//  SetupViewModel.swift
//  lucky7
//
//  Created by Andrian on 29/05/26.
//

import Foundation
import Combine

@MainActor
final class SetupViewModel: ObservableObject {
    struct Preset: Identifiable, Equatable {
        let id: String
        let label: String
        let minutes: Int
        let subtitle: String
    }

    static let presets: [Preset] = [
        Preset(id: "quick", label: "Quick Sprint", minutes: 25, subtitle: "Short focused burst"),
        Preset(id: "standard", label: "Standard", minutes: 45, subtitle: "Balanced session"),
        Preset(id: "deep", label: "Deep Work", minutes: 90, subtitle: "Long deep work")
    ]

    @Published var selectedPreset: Preset = SetupViewModel.presets[0]
    @Published var customMinutes: Int = 25
    @Published var useCustom: Bool = false

    var minutes: Int {
        useCustom ? max(1, customMinutes) : selectedPreset.minutes
    }

    var plannedDuration: TimeInterval {
        TimeInterval(minutes * 60)
    }

    func selectPreset(_ preset: Preset) {
        selectedPreset = preset
        useCustom = false
    }

    func selectCustom() {
        useCustom = true
    }
}
