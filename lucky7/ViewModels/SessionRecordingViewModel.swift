//
//  SessionRecordingViewModel.swift
//  lucky7
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class SessionRecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isExporting = false
    @Published var finalVideoURL: URL?
    /// Persistent text-free slice for weekly/monthly recaps (set after export completes).
    @Published var rawClipURL: URL?
    @Published var previewFrames: [UIImage] = []
    @Published var cameraReady = false
    @Published var permissionDenied = false
    @Published var savedToPhotos = false
    /// Photos-library local id for the saved wrap, persisted on the Session so deleting
    /// the session can also remove the copy from the user's library.
    @Published var photoAssetId: String?
    @Published var lastError: String?
    @Published var statusMessage: String?

    private let timelapseManager = TimelapseManager()
    private let exportEngine = ExportEngine.shared
    private var plannedSessionSeconds: TimeInterval = 0
    private var recordedWallClockSeconds: TimeInterval = 0
    private var didCaptureThisSession = false
    private var exportCompletions: [() -> Void] = []
    // Kept until the user titles the session, so the wrap can be re-rendered with the title.
    private var retainedRawURL: URL?
    private var lastExportFrameCount: Int = 0

    var captureSession: AVCaptureSession {
        timelapseManager.captureSession
    }

    var capturedFrameCount: Int {
        timelapseManager.currentFrameCount
    }

    func prepareCamera() {
        timelapseManager.requestPermissionAndConfigure { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                self.cameraReady = granted
                self.permissionDenied = !granted
                if granted {
                    self.timelapseManager.startRunning()
                    self.statusMessage = nil
                } else {
                    self.lastError = "Camera access is required to record."
                }
            }
        }
    }

    func switchCamera() {
        timelapseManager.switchCamera()
    }

    func stopCamera() {
        timelapseManager.stopRunning()
    }

    func startRecording(plannedSessionSeconds: TimeInterval) {
        guard cameraReady else {
            lastError = "Camera is not ready yet."
            return
        }
        guard !isRecording else { return }

        finalVideoURL = nil
        previewFrames = []
        lastError = nil
        savedToPhotos = false
        photoAssetId = nil
        statusMessage = "Recording…"
        self.plannedSessionSeconds = max(plannedSessionSeconds, 60)
        recordedWallClockSeconds = 0

        timelapseManager.startRecording(plannedSessionSeconds: self.plannedSessionSeconds) { [weak self] started in
            Task { @MainActor in
                guard let self else { return }
                if started {
                    self.isRecording = true
                    self.didCaptureThisSession = true
                    ScreenWakeLock.setActive(true)
                    AccessibilitySupport.announce("Recording started")
                } else {
                    self.lastError = "Could not start recording."
                    self.statusMessage = nil
                }
            }
        }
    }

    func pauseRecording() {
        timelapseManager.capturePaused = true
        timelapseManager.beginPause()
        statusMessage = "Recording paused"
        AccessibilitySupport.announce("Recording paused")
    }

    func resumeRecording() {
        timelapseManager.endPause()
        timelapseManager.capturePaused = false
        statusMessage = "Recording…"
        AccessibilitySupport.announce("Recording resumed")
    }

    func stopRecordingAndExport(
        wallClockSeconds: TimeInterval? = nil,
        completion: @escaping () -> Void
    ) {
        if let wallClockSeconds {
            recordedWallClockSeconds = wallClockSeconds
        }

        exportCompletions.append(completion)

        if isExporting {
            return
        }

        guard isRecording || didCaptureThisSession else {
            finishExportCompletions()
            return
        }

        isRecording = false
        isExporting = true
        ScreenWakeLock.setActive(true)
        statusMessage = "Saving your session video…"
        AccessibilitySupport.announce("Recording stopped. Saving your video")

        timelapseManager.stopRecording { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                guard let rawURL = result.url, result.frameCount > 0 else {
                    self.isExporting = false
                    self.didCaptureThisSession = false
                    self.lastError = "No video was captured. Record for a few seconds on a real device, then end the session."
                    self.statusMessage = nil
                    self.finishExportCompletions()
                    return
                }

                let wallClock = self.recordedWallClockSeconds > 0
                    ? self.recordedWallClockSeconds
                    : 0
                let planned = self.plannedSessionSeconds

                self.exportEngine.generateWrappedVideo(
                    rawVideoURL: rawURL,
                    capturedFrameCount: result.frameCount,
                    overlay: self.makeOverlay(durationSeconds: wallClock),
                    sessionWallClockSeconds: wallClock > 0 ? wallClock : nil,
                    plannedSessionSeconds: planned > 0 ? planned : nil
                ) { [weak self] finalURL in
                    Task { @MainActor in
                        guard let self else { return }

                        self.isExporting = false

                        guard let finalURL else {
                            self.lastError = "Could not stitch session video."
                            self.statusMessage = nil
                            self.didCaptureThisSession = false
                            self.finishExportCompletions()
                            return
                        }

                        self.finalVideoURL = finalURL
                        self.previewFrames = Self.extractPreviewFrames(from: finalURL, count: 3)
                        self.didCaptureThisSession = false
                        self.statusMessage = "Video saved"
                        AccessibilitySupport.announce("Export completed")
                        self.lastExportFrameCount = result.frameCount
                        // Keep the raw so the wrap can be re-rendered with the title later
                        // (and so the Photos copy is the titled one — see reexportWithTitle).
                        self.retainedRawURL = rawURL

                        // Persist a short text-free slice for weekly/monthly recaps.
                        let sliceURL = WrapStorage.newSessionSliceURL()
                        Task { [weak self] in
                            let ok = await ExportEngine.shared.generateCleanSlice(
                                rawVideoURL: rawURL,
                                sliceSeconds: WrapRollupService.sliceSeconds,
                                outputURL: sliceURL
                            )
                            await MainActor.run {
                                if ok { self?.rawClipURL = sliceURL }
                            }
                        }

                        self.finishExportCompletions()
                    }
                }
            }
        }
    }

    private func finishExportCompletions() {
        let completions = exportCompletions
        exportCompletions.removeAll()
        ScreenWakeLock.release()
        completions.forEach { $0() }
    }

    func resetForNewSession() {
        ScreenWakeLock.release()
        isRecording = false
        isExporting = false
        finalVideoURL = nil
        rawClipURL = nil
        if let raw = retainedRawURL { try? FileManager.default.removeItem(at: raw) }
        retainedRawURL = nil
        lastExportFrameCount = 0
        previewFrames = []
        lastError = nil
        savedToPhotos = false
        photoAssetId = nil
        statusMessage = nil
        plannedSessionSeconds = 0
        recordedWallClockSeconds = 0
        didCaptureThisSession = false
        exportCompletions.removeAll()
        timelapseManager.capturePaused = false
    }

    var wrappedDurationSeconds: TimeInterval {
        if let url = finalVideoURL {
            let asset = AVURLAsset(url: url)
            return CMTimeGetSeconds(asset.duration)
        }
        return AppConstants.wrappedDurationSeconds(frameCount: timelapseManager.lastCapturedFrameCount)
    }


    private func saveToPhotosIfPossible(videoURL: URL) async {
        do {
            photoAssetId = try await PhotoLibrarySaver.saveVideo(at: videoURL)
            savedToPhotos = true
            statusMessage = "Saved to Photos"
            AccessibilitySupport.announce("Saved to Photos")
            print("SessionRecording: saved wrap to Photos")
        } catch {
            print("SessionRecording: Photos save failed – \(error.localizedDescription)")
            // Video is still available in-app via finalVideoURL and Share.
            lastError = error.localizedDescription
        }
    }

    static func extractPreviewFrames(from url: URL, count: Int) -> [UIImage] {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        let totalSeconds = max(CMTimeGetSeconds(asset.duration), 0.1)
        var images: [UIImage] = []

        for index in 0..<count {
            let fraction = count == 1 ? 0.5 : Double(index) / Double(count - 1)
            let seconds = totalSeconds * fraction
            let time = CMTime(seconds: seconds, preferredTimescale: 600)

            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                images.append(UIImage(cgImage: cgImage))
            }
        }

        return images
    }

    private func makeOverlay(durationSeconds: TimeInterval, title: String = "Untitled session") -> ExportEngine.WrappedVideoOverlay {
        // Big number = the actual focus length of the session (not the short timelapse).
        let durationText = TimeFormatter.shortDuration(max(durationSeconds, 0))

        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.dateFormat = "d MMM yyyy"
        let date = dateFormatter.string(from: Date())

        return ExportEngine.WrappedVideoOverlay(
            header: title.isEmpty ? "Untitled session" : title,
            duration: durationText,
            subtitle: date
        )
    }

    /// Re-renders the session wrap with the user's title (entered after the first export)
    /// and saves the titled version to Photos.
    func reexportWithTitle(_ title: String, durationSeconds: TimeInterval = 0) {
        guard let raw = retainedRawURL else { return }
        retainedRawURL = nil
        isExporting = true
        // Prefer the session's actual duration; fall back to the recorded wall-clock.
        let secs = durationSeconds > 0 ? durationSeconds : recordedWallClockSeconds
        exportEngine.generateWrappedVideo(
            rawVideoURL: raw,
            capturedFrameCount: lastExportFrameCount,
            overlay: makeOverlay(durationSeconds: secs, title: title)
        ) { [weak self] finalURL in
            Task { @MainActor in
                guard let self else { return }
                self.isExporting = false
                if let finalURL {
                    self.finalVideoURL = finalURL
                    await self.saveToPhotosIfPossible(videoURL: finalURL)
                }
                try? FileManager.default.removeItem(at: raw)
            }
        }
    }
}
