//
//  SessionEndRecovery.swift
//  lucky7
//

import Foundation

enum SessionEndRecovery {
    private static let pendingSessionKey = "rushhour.pendingSessionDetailsId"

    static var pendingSessionID: UUID? {
        guard
            let raw = UserDefaults.standard.string(forKey: pendingSessionKey),
            let id = UUID(uuidString: raw)
        else { return nil }
        return id
    }

    static func markPending(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: pendingSessionKey)
        RecordingDiagnostics.log("Recovery pending session=\(id)")
    }

    static func clear(_ id: UUID? = nil) {
        if let id, pendingSessionID != id { return }
        if let existing = pendingSessionID {
            RecordingDiagnostics.log("Recovery cleared session=\(existing)")
        }
        UserDefaults.standard.removeObject(forKey: pendingSessionKey)
    }
}

