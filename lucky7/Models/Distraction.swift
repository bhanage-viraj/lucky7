// Models/Distraction.swift
// Placeholder for Distraction model

import Foundation
import SwiftData

@Model
final class Distraction: Identifiable {
    var id: UUID
    var sessionId: UUID            // Foreign key linking to Session
    
    var appOpened: String          // Name of the app they tried to open
    var reason: String             // The text they inputted in the prompt
    
    var startTime: Date            // When they left the focus app
    var endTime: Date?             // When they returned to the focus app
    
    var distractionDuration: TimeInterval {
        return startTime.intervalInSeconds(to: endTime ?? Date())
    }

    init(id: UUID = UUID(), sessionId: UUID, appOpened: String, reason: String, startTime: Date = Date(), endTime: Date? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.appOpened = appOpened
        self.reason = reason
        self.startTime = startTime
        self.endTime = endTime
    }
}
