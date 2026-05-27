//
//  Breaks.swift
//  lucky7
//
//  Created by Kadek Belvanatha Gargita Satwikananda on 26/05/26.
//

// Models/Distraction.swift
// Placeholder for Distraction model

import Foundation
import SwiftData

@Model
final class Breaks: Identifiable {
    var id: UUID
    var sessionId: UUID            // Foreign key linking to Session
        
    var startTime: Date            // When they left the focus app
    var endTime: Date?             // When they returned to the focus app
    
    var breakDuration: TimeInterval {
        return startTime.intervalInSeconds(to: endTime ?? Date())
    }

    init(id: UUID = UUID(), sessionId: UUID, startTime: Date = Date(), endTime: Date? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.startTime = startTime
        self.endTime = endTime
    }
}
