// Models/Session.swift
// Placeholder for Session model

import Foundation
import SwiftData

@Model
final class Session: Identifiable {
    var id: UUID
    var userId: UUID
    
    // Configured before starting
    var duration: TimeInterval     // e.g., 1500 seconds (25 mins)
    var actualDuration: TimeInterval {
        return startTime.intervalInSeconds(to: endTime ?? Date())
    }
    
    // Set when session starts/ends
    var startTime: Date
    var endTime: Date?             // Optional because it hasn't ended yet when it starts
    
    // Linked Media
    var videoWrapId: UUID?         // Links to the final Timelapse once generated
    var wrappedVideoPath: String?  // Temp-file path to the 30s wrapped export
    var photoAssetId: String?      // Photos-library local id for the saved wrap (for deletion)
    // Persistent, TEXT-FREE short slice (1080×1920) used to build weekly/monthly recaps.
    // Pruned once both its weekly and monthly recaps have been generated.
    var rawClipPath: String?

    var title: String
    var summary: String

    // User-uploaded activity snapshots. Stored as JPEG data outside the DB
    // file via externalStorage so large images don't bloat the DB.
    @Attribute(.externalStorage) var snapshotImages: [Data]

    init(id: UUID = UUID(), userId: UUID, duration: TimeInterval, startTime: Date = Date(), endTime: Date? = nil, videoWrapId: UUID? = nil, wrappedVideoPath: String? = nil, photoAssetId: String? = nil, rawClipPath: String? = nil, title: String = "", summary: String = "", snapshotImages: [Data] = []) {
        self.id = id
        self.userId = userId
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.videoWrapId = videoWrapId
        self.wrappedVideoPath = wrappedVideoPath
        self.photoAssetId = photoAssetId
        self.rawClipPath = rawClipPath
        self.title = title
        self.summary = summary
        self.snapshotImages = snapshotImages
    }
}
