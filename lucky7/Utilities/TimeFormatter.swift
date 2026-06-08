// Utilities/TimeFormatter.swift

import Foundation

/// Hello I am Antonio
enum TimeFormatter {
    // Long form, e.g. "3 hours 20 minutes", "45 minutes".
    static func longDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) minute\(minutes == 1 ? "" : "s")"
        }
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }

    // Compact form, e.g. "35h 20m", "50m".
    static func shortDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
