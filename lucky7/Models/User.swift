// Models/User.swift
// Placeholder for User model

import Foundation


struct User: Identifiable, Codable {
    let id: UUID
    var username: String
    var name: String
}
