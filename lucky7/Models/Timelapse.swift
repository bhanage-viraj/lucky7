// Models/Timelapse.swift
// Placeholder for Timelapse model

import Foundation


final class Timelapse: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID            // Foreign key linking to Session
    
    // Stores local file paths to the video chunks before they are stitched,
    // or the single path to the final stitched video.
    var videoPaths: [String] 

    init(id: UUID = UUID(), sessionId: UUID, videoPaths: [String] = []) {
        self.id = id
        self.sessionId = sessionId
        self.videoPaths = videoPaths
    }
}
