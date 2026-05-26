// Models/Task.swift
// Placeholder for Task model

import Foundation

struct Task: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID            // Foreign key linking to Session
    var description: String
}
