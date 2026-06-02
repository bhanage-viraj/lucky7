//
//  AppConstants.swift
//  lucky7
//

import Foundation

enum AppConstants {
    /// Max wrap length for long sessions. Shorter early-ended sessions keep their real duration.
    static let wrappedVideoDurationSeconds: TimeInterval = 30

    /// Camera delivers ~30 frames per second; we use this to plan sampling during capture.
    static let cameraFramesPerSecond: Double = 30

    /// Rough cap for the raw timelapse file before export (export still outputs exactly 30s).
    static let maxRawTimelapseSeconds: TimeInterval = 120
}
