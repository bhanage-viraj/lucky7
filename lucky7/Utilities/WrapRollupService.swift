// Utilities/WrapRollupService.swift
// Rolls completed weeks/months up into recap videos, then prunes the bulky per-session
// source slices once they're no longer needed. Safe to call on every launch.

import Foundation
import SwiftData

@MainActor
enum WrapRollupService {

    /// ~2.5s text-free slice kept per session — the durable rollup source.
    static let sliceSeconds: Double = 2.5

    /// Guards against overlapping runs (launch trigger + screen triggers).
    private static var isRunning = false

    /// Generate any due weekly/monthly recaps and prune slices whose week AND month
    /// recaps both exist. No-op when nothing's due. Safe to call from multiple places.
    static func rollUpIfNeeded(context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let calendar = Calendar.current
        let now = Date()

        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let wraps = (try? context.fetch(FetchDescriptor<PeriodWrap>())) ?? []
        var doneKeys = Set(wraps.map { "\($0.kind)/\($0.periodKey)" })

        let withClips = sessions.filter { WrapStorage.exists($0.rawClipPath) }

        // --- Weekly recaps for completed weeks ---
        let byWeek = Dictionary(grouping: withClips) { s in
            calendar.dateInterval(of: .weekOfYear, for: s.startTime)?.start ?? s.startTime
        }
        for (weekStart, weekSessions) in byWeek {
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart),
                  interval.end <= now else { continue }   // week must have ended
            let key = WrapStorage.weekKey(for: weekStart, calendar: calendar)
            guard !doneKeys.contains("weekly/\(key)") else { continue }
            let label = WrapStorage.weekLabel(start: interval.start, end: interval.end, calendar: calendar)
            if await generate(kind: "weekly", key: key, start: interval.start, end: interval.end,
                              sessions: weekSessions, label: label, context: context) {
                doneKeys.insert("weekly/\(key)")
            }
        }

        // --- Monthly recaps for completed months ---
        let byMonth = Dictionary(grouping: withClips) { s in
            calendar.date(from: calendar.dateComponents([.year, .month], from: s.startTime)) ?? s.startTime
        }
        for (monthStart, monthSessions) in byMonth {
            guard let interval = calendar.dateInterval(of: .month, for: monthStart),
                  interval.end <= now else { continue }   // month must have ended
            let key = WrapStorage.monthKey(for: monthStart, calendar: calendar)
            guard !doneKeys.contains("monthly/\(key)") else { continue }
            let label = WrapStorage.monthLabel(for: monthStart)
            if await generate(kind: "monthly", key: key, start: interval.start, end: interval.end,
                              sessions: monthSessions, label: label, context: context) {
                doneKeys.insert("monthly/\(key)")
            }
        }

        // --- Prune: a session's slice can go once BOTH its week and month recaps exist.
        // (A month-straddling week's recap is built later than the month's, so we wait
        //  for both before deleting — never orphaning a recap of its source.)
        var pruned = false
        for s in withClips {
            let wk = WrapStorage.weekKey(for: s.startTime, calendar: calendar)
            let mk = WrapStorage.monthKey(for: s.startTime, calendar: calendar)
            if doneKeys.contains("weekly/\(wk)"), doneKeys.contains("monthly/\(mk)") {
                WrapStorage.delete(path: s.rawClipPath)
                s.rawClipPath = nil
                pruned = true
            }
        }
        if pruned { try? context.save() }

        // Safety net: remove any slice file no session references (e.g. a session that
        // exited before its path was recorded). Only touch files older than an hour so
        // we never race an in-flight save.
        let referenced = Set(sessions.compactMap { $0.rawClipPath })
        let cutoff = now.addingTimeInterval(-3600)
        if let files = try? FileManager.default.contentsOfDirectory(
            at: WrapStorage.sessionsDir, includingPropertiesForKeys: [.creationDateKey]
        ) {
            for file in files where !referenced.contains(file.path) {
                let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                if created < cutoff { try? FileManager.default.removeItem(at: file) }
            }
        }
    }

    /// Builds one recap, verifies the file exists, then records the `PeriodWrap`.
    private static func generate(
        kind: String, key: String, start: Date, end: Date,
        sessions: [Session], label: String, context: ModelContext
    ) async -> Bool {
        let clips = sessions
            .sorted { $0.startTime < $1.startTime }
            .compactMap { $0.rawClipPath }
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !clips.isEmpty else { return false }

        let totalFocus = sessions.reduce(0.0) { $0 + $1.actualDuration }
        let count = sessions.count

        // Header: weekly → the week's date range; monthly → "<Month> Rewind".
        let header: String
        if kind == "monthly" {
            let mf = DateFormatter()
            mf.locale = .current
            mf.dateFormat = "MMMM"
            header = "\(mf.string(from: start)) Rewind"
        } else {
            header = label
        }

        let overlay = ExportEngine.WrappedVideoOverlay(
            header: header,
            duration: TimeFormatter.shortDuration(totalFocus),
            subtitle: ""
        )

        let maxDuration: Double = (kind == "weekly") ? 45 : 60
        let outputURL = WrapStorage.periodURL(kind: kind, key: key)
        let ok = await ExportEngine.shared.generatePeriodWrap(
            clipURLs: clips, overlay: overlay, maxDurationSeconds: maxDuration, outputURL: outputURL
        )
        // Only record after verifying the output — never prune sources for a wrap that
        // didn't actually materialise.
        guard ok, FileManager.default.fileExists(atPath: outputURL.path) else { return false }

        context.insert(PeriodWrap(
            kind: kind, periodKey: key, periodStart: start, periodEnd: end,
            videoPath: outputURL.path, generatedAt: Date(),
            sourceSessionCount: count, totalFocusSeconds: totalFocus
        ))
        try? context.save()
        return true
    }
}
