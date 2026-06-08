// Utilities/WrapStorage.swift
// Persistent on-disk locations + period-key/label helpers for the recap system.
//
// Layout (Application Support, excluded from iCloud backup):
//   Wraps/sessions/<uuid>.mp4   — text-free per-session slices (the rollup source)
//   Wraps/periods/<kind>_<key>.mp4 — stitched weekly/monthly recaps

import Foundation

enum WrapStorage {

    // MARK: - Directories

    private static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Wraps", isDirectory: true)
    }

    static var sessionsDir: URL { ensure(root.appendingPathComponent("sessions", isDirectory: true)) }
    static var periodsDir: URL { ensure(root.appendingPathComponent("periods", isDirectory: true)) }

    @discardableResult
    private static func ensure(_ dir: URL) -> URL {
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var d = dir
            var values = URLResourceValues()
            values.isExcludedFromBackup = true   // don't bloat the user's iCloud backup
            try? d.setResourceValues(values)
        }
        return dir
    }

    // MARK: - File URLs

    /// A fresh, uniquely-named destination for a per-session slice.
    static func newSessionSliceURL() -> URL {
        sessionsDir.appendingPathComponent("\(UUID().uuidString).mp4")
    }

    /// The destination for a period recap (deterministic per period so re-runs overwrite).
    static func periodURL(kind: String, key: String) -> URL {
        periodsDir.appendingPathComponent("\(kind)_\(key).mp4")
    }

    static func delete(path: String?) {
        guard let path else { return }
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
    }

    static func exists(_ path: String?) -> Bool {
        guard let path else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    // MARK: - Period keys & labels (Calendar.current, matching the analytics screens)

    static func weekKey(for date: Date, calendar: Calendar = .current) -> String {
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }

    /// e.g. "5 – 11 JUNE 2026"
    static func weekLabel(start: Date, end: Date, calendar: Calendar = .current) -> String {
        let last = calendar.date(byAdding: .day, value: -1, to: end) ?? end
        func f(_ d: Date, _ fmt: String) -> String {
            let df = DateFormatter(); df.locale = .current; df.dateFormat = fmt
            return df.string(from: d)
        }
        let label: String
        if calendar.isDate(start, equalTo: last, toGranularity: .month) {
            label = "\(f(start, "d")) – \(f(last, "d MMMM yyyy"))"
        } else if calendar.isDate(start, equalTo: last, toGranularity: .year) {
            label = "\(f(start, "d MMM")) – \(f(last, "d MMM yyyy"))"
        } else {
            label = "\(f(start, "d MMM yyyy")) – \(f(last, "d MMM yyyy"))"
        }
        return label.uppercased()
    }

    /// e.g. "JUNE 2026"
    static func monthLabel(for date: Date) -> String {
        let df = DateFormatter(); df.locale = .current; df.dateFormat = "MMMM yyyy"
        return df.string(from: date).uppercased()
    }
}
