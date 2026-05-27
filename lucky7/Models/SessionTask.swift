// Models/Task.swift
// Placeholder for SessionTask model
// Note: renamed from `Task` to avoid shadowing Swift Concurrency's `Task`.

import Foundation

final class SessionTask: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID            // Foreign key linking to Session
    var description: String

    init(id: UUID = UUID(), sessionId: UUID, description: String) {
        self.id = id
        self.sessionId = sessionId
        self.description = description
    }
}
