// Models/Session.swift
// Placeholder for Session model

import Foundation


final class Session: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    
    // Configured before starting
    var duration: TimeInterval     // e.g., 1500 seconds (25 mins)
    var appsAllowed: [AllowedApp]
    
    // Set when session starts/ends
    var startTime: Date
    var endTime: Date?             // Optional because it hasn't ended yet when it starts
    
    // Linked Media
    var videoWrapId: UUID?         // Links to the final Timelapse once generated
    
    // Note: 'breaks' array has been removed as requested.

    init(id: UUID = UUID(), userId: UUID, duration: TimeInterval, appsAllowed: [AllowedApp], startTime: Date = Date(), endTime: Date? = nil, videoWrapId: UUID? = nil) {
        self.id = id
        self.userId = userId
        self.duration = duration
        self.appsAllowed = appsAllowed
        self.startTime = startTime
        self.endTime = endTime
        self.videoWrapId = videoWrapId
    }
}
