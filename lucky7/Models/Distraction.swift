// Models/Distraction.swift
// Placeholder for Distraction model

import Foundation


struct Distraction: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID            // Foreign key linking to Session
    
    var appOpened: String          // Name of the app they tried to open
    var reason: String             // The text they inputted in the prompt
    
    var startTime: Date            // When they left the focus app
    var endTime: Date?             // When they returned to the focus app
}
