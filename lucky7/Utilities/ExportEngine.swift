//
//  ExportEngine.swift
//  lucky7
//
//  Raw timelapse is already timed at 60 fps (frame N → t = N/60).
//  Export re-encodes to a clean MP4 with duration = frameCount / 60.
//

import AVFoundation
import UIKit

final class ExportEngine {
    static let shared = ExportEngine()

    private init() {}

    func generateWrappedVideo(
        rawVideoURL: URL,
        capturedFrameCount: Int,
        overlay: WrappedVideoOverlay? = nil,
        sessionWallClockSeconds: TimeInterval? = nil,
        plannedSessionSeconds: TimeInterval? = nil,
        completion: @escaping (URL?) -> Void
    ) {
        let frameCount = max(capturedFrameCount, 0)
        let outputSeconds = AppConstants.wrappedDurationSeconds(frameCount: frameCount)

        guard frameCount > 0, outputSeconds > 0 else {
            completion(nil)
            return
        }

        let asset = AVURLAsset(url: rawVideoURL)

        Task {
            do {
                let sourceDuration = try await asset.load(.duration)
                let rawSeconds = max(CMTimeGetSeconds(sourceDuration), 0.1)
                let targetDuration = CMTime(seconds: outputSeconds, preferredTimescale: 600)

                if let wall = sessionWallClockSeconds, let planned = plannedSessionSeconds {
                    print(
                        String(
                            format: "ExportEngine: %.0fs of %.0fs planned → %d frames → %.2fs @ %.0ffps",
                            wall,
                            planned,
                            frameCount,
                            outputSeconds,
                            AppConstants.wrappedOutputFPS
                        )
                    )
                } else {
                    print(
                        String(
                            format: "ExportEngine: %d frames → %.2fs @ %.0ffps",
                            frameCount,
                            outputSeconds,
                            AppConstants.wrappedOutputFPS
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

                if abs(rawSeconds - outputSeconds) > 0.05 {
                    compositionTrack.scaleTimeRange(
                        CMTimeRange(start: .zero, duration: sourceDuration),
                        toDuration: targetDuration
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

                exportSession.videoComposition = try await makePortraitVideoComposition(
                    for: composition,
                    sourceVideoTrack: videoTrack,
                    overlay: overlay
                )

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

    // MARK: - Portrait output + overlay

    struct WrappedVideoOverlay {
        let titleTop: String
        let durationCenter: String
        let dateCenter: String
        let footer: String
    }

    private func makePortraitVideoComposition(
        for composition: AVComposition,
        sourceVideoTrack: AVAssetTrack,
        overlay: WrappedVideoOverlay?
    ) async throws -> AVMutableVideoComposition {
        // Export in portrait 9:16 always. Portrait inputs fill; landscape inputs letterbox.
        let renderSize = CGSize(width: 1080, height: 1920)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(AppConstants.wrappedOutputFPS))
        videoComposition.renderSize = renderSize

        // Compute an oriented rect for the source track.
        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        let naturalSize = try await sourceVideoTrack.load(.naturalSize)
        let sourceRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let orientedSize = CGSize(width: abs(sourceRect.width), height: abs(sourceRect.height))

        // Normalize so oriented video starts at (0,0).
        let normalize = preferredTransform.concatenating(
            CGAffineTransform(translationX: -sourceRect.origin.x, y: -sourceRect.origin.y)
        )

        // Decide fill vs fit.
        // If the oriented video is portrait-ish, fill the portrait canvas.
        // If it's landscape-ish, fit (letterbox top/bottom).
        let isPortraitish = orientedSize.height >= orientedSize.width
        let scaleX = renderSize.width / max(orientedSize.width, 1)
        let scaleY = renderSize.height / max(orientedSize.height, 1)
        let scale = isPortraitish ? max(scaleX, scaleY) : min(scaleX, scaleY)

        let scaledSize = CGSize(width: orientedSize.width * scale, height: orientedSize.height * scale)
        let tx = (renderSize.width - scaledSize.width) / 2
        let ty = (renderSize.height - scaledSize.height) / 2

        let finalTransform = normalize
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: tx, y: ty))

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)

        guard let compVideoTrack = composition.tracks(withMediaType: .video).first else {
            return videoComposition
        }

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
        layerInstruction.setTransform(finalTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // Layers
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.backgroundColor = UIColor.black.cgColor

        let videoLayer = CALayer()
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

        if let overlay {
            let overlayLayer = makeOverlayLayer(renderSize: renderSize, overlay: overlay)
            parentLayer.addSublayer(overlayLayer)
        }

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        return videoComposition
    }

    private func makeOverlayLayer(renderSize: CGSize, overlay: WrappedVideoOverlay) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: renderSize)
        layer.masksToBounds = true

        let maxSide = max(renderSize.width, renderSize.height)
        let padding: CGFloat = maxSide * 0.06

        func gothic(_ size: CGFloat) -> UIFont {
            UIFont(name: "SpecialGothicExpandedOne-Regular", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: .black)
        }

        func textLayer(_ text: String, font: UIFont, frame: CGRect, alpha: CGFloat = 1) -> CATextLayer {
            let t = CATextLayer()
            t.string = text
            t.alignmentMode = .center
            t.isWrapped = true
            t.contentsScale = UIScreen.main.scale
            t.foregroundColor = UIColor.white.withAlphaComponent(alpha).cgColor
            t.shadowColor = UIColor.black.cgColor
            t.shadowOpacity = 0.9
            t.shadowRadius = 6
            t.shadowOffset = CGSize(width: 0, height: 2)
            t.font = font
            t.fontSize = font.pointSize
            t.frame = frame
            return t
        }

        // TOP: Title
        let titleFont = gothic(maxSide * 0.035)
        let titleFrame = CGRect(
            x: padding,
            y: padding * 0.9,
            width: renderSize.width - padding * 2,
            height: titleFont.pointSize * 1.6
        )
        layer.addSublayer(textLayer(overlay.titleTop.uppercased(), font: titleFont, frame: titleFrame, alpha: 1))

        // CENTER: Duration big + date small (like your mock)
        let durationFont = gothic(maxSide * 0.10)
        let durationFrame = CGRect(
            x: padding,
            y: renderSize.height * 0.18,
            width: renderSize.width - padding * 2,
            height: durationFont.pointSize * 1.2
        )
        layer.addSublayer(textLayer(overlay.durationCenter, font: durationFont, frame: durationFrame, alpha: 1))

        let dateFont = gothic(maxSide * 0.03)
        let dateFrame = CGRect(
            x: padding,
            y: durationFrame.maxY + (maxSide * 0.01),
            width: renderSize.width - padding * 2,
            height: dateFont.pointSize * 1.4
        )
        layer.addSublayer(textLayer(overlay.dateCenter.uppercased(), font: dateFont, frame: dateFrame, alpha: 0.85))

        // BOTTOM: footer with time range + Rush Hour
        let footerFont = gothic(maxSide * 0.04)
        let footerFrame = CGRect(
            x: padding,
            y: renderSize.height - padding - footerFont.pointSize * 1.8,
            width: renderSize.width - padding * 2,
            height: footerFont.pointSize * 1.8
        )
        layer.addSublayer(textLayer(overlay.footer.uppercased(), font: footerFont, frame: footerFrame, alpha: 1))

        return layer
    }
}
