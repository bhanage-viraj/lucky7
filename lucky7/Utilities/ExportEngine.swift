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

    // MARK: - Period recaps (weekly / monthly)

    /// Produces a short, TEXT-FREE, portrait-normalised (1080×1920) slice of a raw
    /// timelapse — the durable per-session source for weekly/monthly recaps.
    func generateCleanSlice(rawVideoURL: URL, sliceSeconds: Double, outputURL: URL) async -> Bool {
        let asset = AVURLAsset(url: rawVideoURL)
        do {
            let duration = try await asset.load(.duration)
            let totalSeconds = CMTimeGetSeconds(duration)
            guard totalSeconds > 0 else { return false }

            let slice = min(sliceSeconds, totalSeconds)
            let startSeconds = max(0, (totalSeconds - slice) / 2)   // centered
            let timeRange = CMTimeRange(
                start: CMTime(seconds: startSeconds, preferredTimescale: 600),
                duration: CMTime(seconds: slice, preferredTimescale: 600)
            )

            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { return false }

            let composition = AVMutableComposition()
            guard let compTrack = composition.addMutableTrack(
                withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { return false }
            try compTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
            compTrack.preferredTransform = try await videoTrack.load(.preferredTransform)

            let videoComposition = try await makePortraitVideoComposition(
                for: composition, sourceVideoTrack: videoTrack, overlay: nil
            )

            return await export(composition: composition, videoComposition: videoComposition, to: outputURL)
        } catch {
            print("ExportEngine.generateCleanSlice: \(error.localizedDescription)")
            return false
        }
    }

    /// Concatenates the (already 1080×1920, text-free, 60 fps) per-session slices into one
    /// video and burns a single period-level overlay (total focus time / period label /
    /// footer). Each clip is trimmed so the whole recap never exceeds `maxDurationSeconds`.
    func generatePeriodWrap(
        clipURLs: [URL],
        overlay: WrappedVideoOverlay,
        maxDurationSeconds: Double,
        outputURL: URL
    ) async -> Bool {
        guard !clipURLs.isEmpty else { return false }
        let renderSize = CGSize(width: 1080, height: 1920)
        // Share the budget evenly so every session is represented within the cap.
        let perClipSeconds = maxDurationSeconds / Double(clipURLs.count)

        let composition = AVMutableComposition()
        guard let compTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { return false }

        var cursor = CMTime.zero
        do {
            for url in clipURLs {
                let asset = AVURLAsset(url: url)
                guard let track = try await asset.loadTracks(withMediaType: .video).first else { continue }
                let dur = CMTimeGetSeconds(try await asset.load(.duration))
                let take = min(dur, perClipSeconds)
                guard take > 0 else { continue }
                let range = CMTimeRange(start: .zero, duration: CMTime(seconds: take, preferredTimescale: 600))
                try compTrack.insertTimeRange(range, of: track, at: cursor)
                cursor = CMTimeAdd(cursor, range.duration)
            }
        } catch {
            print("ExportEngine.generatePeriodWrap insert: \(error.localizedDescription)")
            return false
        }
        guard cursor > .zero else { return false }

        // The slices are already 1080×1920 with identity transform, so the composition is
        // just the overlay on top of a pass-through video layer. 60 fps via frameDuration.
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(AppConstants.wrappedOutputFPS))
        videoComposition.renderSize = renderSize

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        instruction.layerInstructions = [AVMutableVideoCompositionLayerInstruction(assetTrack: compTrack)]
        videoComposition.instructions = [instruction]

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.backgroundColor = UIColor.black.cgColor
        let videoLayer = CALayer()
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(makeOverlayLayer(renderSize: renderSize, overlay: overlay))
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer, in: parentLayer
        )

        return await export(composition: composition, videoComposition: videoComposition, to: outputURL)
    }

    private func export(
        composition: AVComposition,
        videoComposition: AVMutableVideoComposition,
        to outputURL: URL
    ) async -> Bool {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            return false
        }
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        session.videoComposition = videoComposition
        await session.export()
        if session.status != .completed {
            print("ExportEngine.export failed: \(session.error?.localizedDescription ?? "unknown")")
        }
        return session.status == .completed
    }

    // MARK: - Portrait output + overlay

    struct WrappedVideoOverlay {
        /// Top line — the session title, the week's date range, or "<Month> Rewind".
        let header: String
        /// Large hero line — total focus duration, e.g. "3h 20m".
        let duration: String
        /// Small line under the duration — the date for session wraps. Empty hides it,
        /// so weekly/monthly wraps show only header + duration.
        let subtitle: String
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

        func paragraphStyle(for font: UIFont, lineBreakMode: NSLineBreakMode) -> NSMutableParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.lineBreakMode = lineBreakMode
            style.minimumLineHeight = font.pointSize * 1.10
            style.maximumLineHeight = font.pointSize * 1.10
            return style
        }

        func attributedText(
            _ text: String,
            font: UIFont,
            alpha: CGFloat,
            lineBreakMode: NSLineBreakMode
        ) -> NSAttributedString {
            NSAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .foregroundColor: UIColor.white.withAlphaComponent(alpha),
                    .paragraphStyle: paragraphStyle(for: font, lineBreakMode: lineBreakMode)
                ]
            )
        }

        func measuredTextWidth(_ text: String, font: UIFont) -> CGFloat {
            let bounds = (text as NSString).boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: font.lineHeight * 1.4),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            return ceil(bounds.width)
        }

        func ellipsizedLine(_ text: String, font: UIFont, maxWidth: CGFloat) -> String {
            let ellipsis = "..."
            var base = text.trimmingCharacters(in: .whitespaces)

            guard measuredTextWidth(base, font: font) > maxWidth else { return base }
            guard measuredTextWidth(ellipsis, font: font) <= maxWidth else { return "" }

            while !base.isEmpty {
                if measuredTextWidth(base + ellipsis, font: font) <= maxWidth {
                    return base + ellipsis
                }
                base.removeLast()
            }

            return ellipsis
        }

        func wrappedHeaderLines(
            _ text: String,
            font: UIFont,
            maxWidth: CGFloat,
            maxLines: Int,
            truncatesOverflow: Bool = false
        ) -> (lines: [String], didFit: Bool) {
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return ([], true) }

            var lines: [String] = []
            var current = ""
            var didFit = true

            for character in trimmedText {
                let next = current + String(character)
                if current.isEmpty || measuredTextWidth(next, font: font) <= maxWidth {
                    current = next
                    continue
                }

                if lines.count == maxLines - 1 {
                    lines.append(
                        truncatesOverflow
                        ? ellipsizedLine(next, font: font, maxWidth: maxWidth)
                        : current.trimmingCharacters(in: .whitespaces)
                    )
                    didFit = false
                    current = ""
                    break
                }

                let line = current.trimmingCharacters(in: .whitespaces)
                if !line.isEmpty {
                    lines.append(line)
                }

                if lines.count >= maxLines {
                    didFit = false
                    current = ""
                    break
                }

                current = String(character).trimmingCharacters(in: .whitespaces)
            }

            let lastLine = current.trimmingCharacters(in: .whitespaces)
            if !lastLine.isEmpty {
                if lines.count < maxLines {
                    lines.append(lastLine)
                } else {
                    if truncatesOverflow, let last = lines.indices.last {
                        lines[last] = ellipsizedLine(lines[last] + lastLine, font: font, maxWidth: maxWidth)
                    }
                    didFit = false
                }
            }

            return (lines, didFit)
        }

        func fittedHeaderLayout(_ text: String, maxLines: Int, width: CGFloat) -> (font: UIFont, text: String, lineCount: Int) {
            let baseSize = maxSide * 0.040
            let minimumSize = maxSide * 0.018
            var size = baseSize

            while size > minimumSize {
                let font = gothic(size)
                let wrapped = wrappedHeaderLines(text, font: font, maxWidth: width, maxLines: maxLines)
                if wrapped.didFit, !wrapped.lines.isEmpty {
                    return (font, wrapped.lines.joined(separator: "\n"), wrapped.lines.count)
                }
                size -= 2
            }

            let font = gothic(minimumSize)
            let wrapped = wrappedHeaderLines(text, font: font, maxWidth: width, maxLines: maxLines, truncatesOverflow: true)
            let lines = wrapped.lines.isEmpty ? [text] : wrapped.lines
            return (font, lines.joined(separator: "\n"), lines.count)
        }

        func textLayer(
            _ text: String,
            font: UIFont,
            frame: CGRect,
            alpha: CGFloat = 1,
            lineBreakMode: NSLineBreakMode = .byWordWrapping
        ) -> CATextLayer {
            let t = CATextLayer()
            t.string = attributedText(text, font: font, alpha: alpha, lineBreakMode: lineBreakMode)
            t.alignmentMode = .center
            t.isWrapped = true
            t.contentsScale = UIScreen.main.scale
            t.truncationMode = .none
            t.shadowColor = UIColor.black.cgColor
            t.shadowOpacity = 0.9
            t.shadowRadius = 6
            t.shadowOffset = CGSize(width: 0, height: 2)
            t.font = font
            t.fontSize = font.pointSize
            t.frame = frame
            return t
        }

        // The Core Animation canvas used by AVVideoCompositionCoreAnimationTool has a
        // BOTTOM-LEFT origin: a layer's frame.y is its BOTTOM edge and larger y sits higher
        // on screen. So to stack header → duration → date from the TOP, we anchor the header
        // near the top (high y) and step y DOWN for each following line.
        let contentWidth = renderSize.width - padding * 2
        let topMargin = renderSize.height * 0.06

        // 1. Header — session title, week range, or "<Month> Rewind" (topmost line).
        let headerMaxLines = 2
        let headerWrapWidth = contentWidth * 0.84
        let headerLayout = fittedHeaderLayout(overlay.header, maxLines: headerMaxLines, width: headerWrapWidth)
        let headerFont = headerLayout.font
        let headerLineHeight = headerFont.pointSize * 1.10
        let headerHeight = headerLineHeight * CGFloat(max(headerLayout.lineCount, 1)) + headerFont.pointSize * 0.20
        let headerY = renderSize.height - topMargin - headerHeight
        layer.addSublayer(textLayer(
            headerLayout.text, font: headerFont,
            frame: CGRect(x: padding, y: headerY, width: contentWidth, height: headerHeight),
            alpha: 1,
            lineBreakMode: .byCharWrapping
        ))

        // 2. Duration — the large hero line, just below the header.
        let durationFont = gothic(maxSide * 0.085)
        let durationHeight = durationFont.pointSize * 1.15
        let durationY = headerY - maxSide * 0.006 - durationHeight
        layer.addSublayer(textLayer(
            overlay.duration, font: durationFont,
            frame: CGRect(x: padding, y: durationY, width: contentWidth, height: durationHeight),
            alpha: 1
        ))

        // 3. Subtitle (date) — session wraps only; empty on weekly/monthly so it's skipped.
        if !overlay.subtitle.isEmpty {
            let dateFont = gothic(maxSide * 0.026)
            let dateHeight = dateFont.pointSize * 1.4
            let dateY = durationY - maxSide * 0.004 - dateHeight
            layer.addSublayer(textLayer(
                overlay.subtitle, font: dateFont,
                frame: CGRect(x: padding, y: dateY, width: contentWidth, height: dateHeight),
                alpha: 0.9
            ))
        }

        return layer
    }
}
