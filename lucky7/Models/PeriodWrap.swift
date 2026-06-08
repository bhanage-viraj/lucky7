// Models/PeriodWrap.swift
// A generated weekly or monthly recap, stitched from the text-free per-session clips.

import Foundation
import SwiftData

@Model
final class PeriodWrap {
    var id: UUID
    /// "weekly" or "monthly".
    var kind: String
    /// Stable key for the period: weekly = "2026-W23", monthly = "2026-06".
    var periodKey: String
    var periodStart: Date
    /// Exclusive end (start of the next period). The period has "ended" once now >= periodEnd.
    var periodEnd: Date
    /// Path to the stitched, texted recap video (persistent).
    var videoPath: String?
    var generatedAt: Date
    var sourceSessionCount: Int
    var totalFocusSeconds: Double

    init(
        id: UUID = UUID(),
        kind: String,
        periodKey: String,
        periodStart: Date,
        periodEnd: Date,
        videoPath: String? = nil,
        generatedAt: Date = Date(),
        sourceSessionCount: Int = 0,
        totalFocusSeconds: Double = 0
    ) {
        self.id = id
        self.kind = kind
        self.periodKey = periodKey
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.videoPath = videoPath
        self.generatedAt = generatedAt
        self.sourceSessionCount = sourceSessionCount
        self.totalFocusSeconds = totalFocusSeconds
    }
}
