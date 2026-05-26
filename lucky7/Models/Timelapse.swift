// Models/Timelapse.swift
// Placeholder for Timelapse model

import Foundation


struct Timelapse: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID            // Foreign key linking to Session
    
    // Stores local file paths to the video chunks before they are stitched,
    // or the single path to the final stitched video.
    var videoPaths: [String] 
}
