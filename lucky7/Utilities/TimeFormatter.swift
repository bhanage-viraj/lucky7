// Utilities/TimeFormatter.swift

import Foundation

/// Hello I am Antonio
enum TimeFormatter {
    // Long form. Tiers so a sub-minute value never reads as "0 minutes":
    // ≥1h → "3 hours 20 minutes"; <1h → "45 minutes 12 seconds"; <1m → "42 seconds".
    static func longDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return "\(h) hour\(h == 1 ? "" : "s") \(m) minute\(m == 1 ? "" : "s")"
        }
        if m > 0 {
            return "\(m) minute\(m == 1 ? "" : "s") \(s) second\(s == 1 ? "" : "s")"
        }
        return "\(s) second\(s == 1 ? "" : "s")"
    }

    // Compact form. Tiers so a sub-minute value never reads as "0m":
    // ≥1h → "3h 20m"; <1h → "45m 12s"; <1m → "42s".
    static func shortDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
