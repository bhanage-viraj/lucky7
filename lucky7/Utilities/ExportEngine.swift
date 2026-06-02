//
//  ExportEngine.swift
//  lucky7
//
//  Stitches the raw timelapse into one clip:
//  - Long sessions → compressed to max 30s
//  - Early / short sessions → keeps real length (not padded to 30s)
//

import AVFoundation

final class ExportEngine {
    static let shared = ExportEngine()

    private init() {}

    func generateWrappedVideo(
        rawVideoURL: URL,
        sessionWallClockSeconds: TimeInterval? = nil,
        maxTargetDurationInSeconds: TimeInterval = AppConstants.wrappedVideoDurationSeconds,
        completion: @escaping (URL?) -> Void
    ) {
        let asset = AVURLAsset(url: rawVideoURL)

        Task {
            do {
                let sourceDuration = try await asset.load(.duration)
                let rawSeconds = max(CMTimeGetSeconds(sourceDuration), 0.1)
                let maxTarget = max(maxTargetDurationInSeconds, 0.5)

                // Short early-ended session: keep actual length. Long session: cap at 30s.
                let outputSeconds = min(rawSeconds, maxTarget)
                let scaledDuration = CMTime(seconds: outputSeconds, preferredTimescale: 600)

                if let wallClock = sessionWallClockSeconds {
                    print(
                        String(
                            format: "ExportEngine: %.0fs session → %.1fs raw → %.1fs final",
                            wallClock,
                            rawSeconds,
                            outputSeconds
                        )
                    )
                } else {
                    print(
                        String(
                            format: "ExportEngine: %.1fs raw → %.1fs final",
                            rawSeconds,
                            outputSeconds
                        )
                    )
                }

                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    await MainActor.run { completion(nil) }
                    return
                }

                let composition = AVMutableComposition()
                guard let compositionTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    await MainActor.run { completion(nil) }
                    return
                }

                try compositionTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: sourceDuration),
                    of: videoTrack,
                    at: .zero
                )

                compositionTrack.preferredTransform = try await videoTrack.load(.preferredTransform)

                if rawSeconds > outputSeconds + 0.05 {
                    compositionTrack.scaleTimeRange(
                        CMTimeRange(start: .zero, duration: sourceDuration),
                        toDuration: scaledDuration
                    )
                }

                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("wrapped_\(UUID().uuidString).mp4")

                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }

                guard let exportSession = AVAssetExportSession(
                    asset: composition,
                    presetName: AVAssetExportPresetHighestQuality
                ) else {
                    await MainActor.run { completion(nil) }
                    return
                }

                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                exportSession.shouldOptimizeForNetworkUse = true

                await exportSession.export()

                await MainActor.run {
                    if exportSession.status == .completed {
                        completion(outputURL)
                    } else {
                        print("ExportEngine: export failed – \(exportSession.error?.localizedDescription ?? "unknown")")
                        completion(nil)
                    }
                }
            } catch {
                print("ExportEngine: \(error.localizedDescription)")
                await MainActor.run { completion(nil) }
            }
        }
    }
}
