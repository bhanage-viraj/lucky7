// Models/Task.swift
// Placeholder for Task model

import Foundation

final class Task: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID            // Foreign key linking to Session
    var description: String

    init(id: UUID = UUID(), sessionId: UUID, description: String) {
        self.id = id
        self.sessionId = sessionId
        self.description = description
    }
}
