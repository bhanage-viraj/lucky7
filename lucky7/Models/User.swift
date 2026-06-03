// Models/User.swift
// Placeholder for User model

import Foundation


final class User: Identifiable, Codable {
    let id: UUID
    var username: String
    var name: String

    init(id: UUID = UUID(), username: String, name: String) {
        self.id = id
        self.username = username
        self.name = name
    }
}
