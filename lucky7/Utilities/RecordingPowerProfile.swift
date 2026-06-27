import AVFoundation
import Foundation

struct RecordingPowerProfile {
    struct Applied {
        let requestedFPS: Double
        let appliedFPS: Double
        let minSupportedFPS: Double
        let maxSupportedFPS: Double
    }

    let plannedSessionSeconds: TimeInterval
    let captureIntervalSeconds: TimeInterval
    let requestedFPS: Double

    static func recording(plannedSessionSeconds: TimeInterval) -> RecordingPowerProfile {
        let planned = max(plannedSessionSeconds, AppConstants.minimumPlannedSessionSeconds)
        let interval = AppConstants.captureIntervalSeconds(plannedSessionSeconds: planned)
        let fps = min(max(ceil((1 / interval) * 2), 1), 30)
        return RecordingPowerProfile(
            plannedSessionSeconds: planned,
            captureIntervalSeconds: interval,
            requestedFPS: fps
        )
    }

    static var preview: RecordingPowerProfile {
        RecordingPowerProfile(
            plannedSessionSeconds: 0,
            captureIntervalSeconds: 0,
            requestedFPS: 30
        )
    }

    func apply(to device: AVCaptureDevice) throws -> Applied {
        let ranges = device.activeFormat.videoSupportedFrameRateRanges
        let minSupported = ranges.map(\.minFrameRate).min() ?? 1
        let maxSupported = ranges.map(\.maxFrameRate).max() ?? 30
        let appliedFPS = min(max(requestedFPS, minSupported), maxSupported)
        let frameDuration = CMTime(seconds: 1 / appliedFPS, preferredTimescale: 600)

        try device.lockForConfiguration()
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
        device.unlockForConfiguration()

        return Applied(
            requestedFPS: requestedFPS,
            appliedFPS: appliedFPS,
            minSupportedFPS: minSupported,
            maxSupportedFPS: maxSupported
        )
    }
}
