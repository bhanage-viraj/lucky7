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
    private var stopCompletions: [() -> Void] = []
    private var isStoppingRecording = false
    private var isCleanSliceExporting = false
    private var cleanSliceToken = UUID()
    private var cleanSliceRawURL: URL?
    private var rawURLsPendingDeletion: Set<URL> = []
    private var pendingTitleExport: PendingTitleExport?
    private var activeTitleExportTitle: String?
    private var activeTitleExportCompletions: [(URL?) -> Void] = []
    private var activeTitleExportShouldSaveToPhotos = false
    private var completedTitleExportTitle: String?
    private var completedTitleExportSavedToPhotos = false
    // Kept until the user titles the session, so the wrap can be re-rendered with the title.
    private var retainedRawURL: URL?
    private var lastExportFrameCount: Int = 0

    private struct PendingTitleExport {
        let title: String
        let durationSeconds: TimeInterval
        let saveToPhotos: Bool
        let completions: [(URL?) -> Void]
    }

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

    func ensureCameraRunning() {
        timelapseManager.startRunning()
    }

    func startRecording(plannedSessionSeconds: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        guard cameraReady else {
            lastError = "Camera is not ready yet."
            completion?(false)
            return
        }
        guard !isRecording else {
            completion?(true)
            return
        }

        finalVideoURL = nil
        rawClipURL = nil
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
                completion?(started)
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
        timelapseManager.startRunning()
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

        stopCompletions.append(completion)

        if isStoppingRecording {
            return
        }

        guard isRecording || didCaptureThisSession else {
            finishStopCompletions()
            return
        }

        isRecording = false
        isStoppingRecording = true
        ScreenWakeLock.setActive(true)
        statusMessage = "Preparing your session…"
        AccessibilitySupport.announce("Recording stopped. Preparing your session")

        timelapseManager.stopRecording { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isStoppingRecording = false

                guard let rawURL = result.url, result.frameCount > 0 else {
                    let pending = self.pendingTitleExport
                    self.pendingTitleExport = nil
                    self.isExporting = false
                    self.activeTitleExportTitle = nil
                    self.activeTitleExportCompletions.removeAll()
                    self.activeTitleExportShouldSaveToPhotos = false
                    self.didCaptureThisSession = false
                    self.lastError = "No video was captured. Record for a few seconds on a real device, then end the session."
                    self.statusMessage = nil
                    pending?.completions.forEach { $0(nil) }
                    self.finishStopCompletions()
                    return
                }

                self.retainedRawURL = rawURL
                self.lastExportFrameCount = result.frameCount
                self.previewFrames = Self.extractPreviewFrames(from: rawURL, count: 3)
                self.didCaptureThisSession = false
                self.statusMessage = "Ready to save"
                self.startCleanSliceExport(from: rawURL)
                let pending = self.pendingTitleExport
                self.pendingTitleExport = nil
                self.finishStopCompletions()
                if let pending {
                    self.startTitleExport(
                        pending.title,
                        durationSeconds: pending.durationSeconds,
                        saveToPhotos: pending.saveToPhotos,
                        completions: pending.completions
                    )
                } else {
                    self.prepareTitledExport("Untitled session", durationSeconds: self.recordedWallClockSeconds)
                }
            }
        }
    }

    private func finishStopCompletions() {
        let completions = stopCompletions
        stopCompletions.removeAll()
        ScreenWakeLock.release()
        completions.forEach { $0() }
    }

    private func startCleanSliceExport(from rawURL: URL) {
        isCleanSliceExporting = true
        cleanSliceToken = UUID()
        let token = cleanSliceToken
        cleanSliceRawURL = rawURL
        let sliceURL = WrapStorage.newSessionSliceURL()
        Task { [weak self] in
            let ok = await ExportEngine.shared.generateCleanSlice(
                rawVideoURL: rawURL,
                sliceSeconds: WrapRollupService.sliceSeconds,
                outputURL: sliceURL
            )
            await MainActor.run {
                guard let self else { return }
                let isCurrentSlice = self.cleanSliceToken == token
                if ok, isCurrentSlice {
                    self.rawClipURL = sliceURL
                } else {
                    try? FileManager.default.removeItem(at: sliceURL)
                }
                if self.rawURLsPendingDeletion.remove(rawURL) != nil {
                    try? FileManager.default.removeItem(at: rawURL)
                }
                guard isCurrentSlice, self.cleanSliceRawURL == rawURL else { return }

                self.isCleanSliceExporting = false
                self.cleanSliceRawURL = nil
            }
        }
    }

    func resetForNewSession() {
        ScreenWakeLock.release()
        isRecording = false
        isExporting = false
        finalVideoURL = nil
        rawClipURL = nil
        let activeCleanSliceRawURL = cleanSliceRawURL
        cleanSliceToken = UUID()
        isCleanSliceExporting = false
        cleanSliceRawURL = nil
        if let raw = retainedRawURL {
            if activeCleanSliceRawURL == raw {
                rawURLsPendingDeletion.insert(raw)
            } else {
                try? FileManager.default.removeItem(at: raw)
            }
            retainedRawURL = nil
        }
        lastExportFrameCount = 0
        previewFrames = []
        lastError = nil
        savedToPhotos = false
        photoAssetId = nil
        statusMessage = nil
        plannedSessionSeconds = 0
        recordedWallClockSeconds = 0
        didCaptureThisSession = false
        pendingTitleExport = nil
        activeTitleExportTitle = nil
        activeTitleExportCompletions.removeAll()
        activeTitleExportShouldSaveToPhotos = false
        completedTitleExportTitle = nil
        completedTitleExportSavedToPhotos = false
        stopCompletions.removeAll()
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
        guard count > 0 else { return [] }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        let durationSeconds = CMTimeGetSeconds(asset.duration)
        let totalSeconds = durationSeconds.isFinite && durationSeconds > 0 ? durationSeconds : 1
        var images: [UIImage] = []
        let primaryTimes = previewFrameTimes(totalSeconds: totalSeconds, count: count)
        let fallbackTimes = previewFrameFallbackTimes(totalSeconds: totalSeconds)
        var attemptedTimes: [Double] = []

        for seconds in primaryTimes + fallbackTimes {
            guard images.count < count else { break }
            let clampedSeconds = min(max(seconds, 0), totalSeconds)
            guard !attemptedTimes.contains(where: { abs($0 - clampedSeconds) < 0.01 }) else { continue }
            attemptedTimes.append(clampedSeconds)

            let time = CMTime(seconds: clampedSeconds, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                images.append(UIImage(cgImage: cgImage))
            }
        }

        guard !images.isEmpty else { return [] }

        let extractedCount = images.count
        while images.count < count {
            images.append(images[images.count % extractedCount])
        }

        return Array(images.prefix(count))
    }

    private static func previewFrameTimes(totalSeconds: Double, count: Int) -> [Double] {
        guard count > 1 else { return [0] }
        guard count > 2 else {
            return [0, Double.random(in: (totalSeconds * 0.55)...(totalSeconds * 0.95))]
        }

        let middle = Double.random(in: (totalSeconds * 0.33)...(totalSeconds * 0.66))
        let late = Double.random(in: (totalSeconds * 0.70)...(totalSeconds * 0.95))
        return [0, middle, late]
    }

    private static func previewFrameFallbackTimes(totalSeconds: Double) -> [Double] {
        let safeStart = min(max(totalSeconds * 0.02, 0.03), max(totalSeconds * 0.25, 0.03))
        return [
            0,
            safeStart,
            totalSeconds * 0.10,
            totalSeconds * 0.25,
            totalSeconds * 0.40,
            totalSeconds * 0.55,
            totalSeconds * 0.70,
            totalSeconds * 0.85,
            totalSeconds * 0.95
        ]
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

    func prepareTitledExport(_ title: String, durationSeconds: TimeInterval = 0) {
        reexportWithTitle(title, durationSeconds: durationSeconds, saveToPhotos: false)
    }

    /// Re-renders the session wrap with the user's title and optionally saves it to Photos.
    func reexportWithTitle(
        _ title: String,
        durationSeconds: TimeInterval = 0,
        saveToPhotos: Bool = true,
        completion: ((URL?) -> Void)? = nil
    ) {
        let exportTitle = normalizedTitle(title)

        if let finalVideoURL, completedTitleExportTitle == exportTitle {
            finishCachedTitleExport(
                finalVideoURL,
                saveToPhotos: saveToPhotos,
                completion: completion
            )
            return
        }

        guard !isExporting else {
            if activeTitleExportTitle == exportTitle {
                if let completion {
                    activeTitleExportCompletions.append(completion)
                }
                if saveToPhotos {
                    activeTitleExportShouldSaveToPhotos = true
                }
            } else {
                queuePendingTitleExport(
                    title: exportTitle,
                    durationSeconds: durationSeconds,
                    saveToPhotos: saveToPhotos,
                    completion: completion
                )
            }
            return
        }

        guard retainedRawURL != nil, lastExportFrameCount > 0 else {
            if isStoppingRecording {
                isExporting = true
                activeTitleExportTitle = exportTitle
                activeTitleExportCompletions = completion.map { [$0] } ?? []
                activeTitleExportShouldSaveToPhotos = saveToPhotos
                statusMessage = "Generating your Wrap…"
                ScreenWakeLock.setActive(true)
                pendingTitleExport = PendingTitleExport(
                    title: exportTitle,
                    durationSeconds: durationSeconds,
                    saveToPhotos: saveToPhotos,
                    completions: completion.map { [$0] } ?? []
                )
            } else {
                completion?(finalVideoURL)
            }
            return
        }

        startTitleExport(
            exportTitle,
            durationSeconds: durationSeconds,
            saveToPhotos: saveToPhotos,
            completions: completion.map { [$0] } ?? []
        )
    }

    private func normalizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled session" : trimmed
    }

    private func queuePendingTitleExport(
        title: String,
        durationSeconds: TimeInterval,
        saveToPhotos: Bool,
        completion: ((URL?) -> Void)?
    ) {
        let newCompletions = completion.map { [$0] } ?? []
        if let existingPending = pendingTitleExport, existingPending.title == title {
            pendingTitleExport = PendingTitleExport(
                title: title,
                durationSeconds: durationSeconds,
                saveToPhotos: existingPending.saveToPhotos || saveToPhotos,
                completions: existingPending.completions + newCompletions
            )
        } else {
            pendingTitleExport = PendingTitleExport(
                title: title,
                durationSeconds: durationSeconds,
                saveToPhotos: saveToPhotos,
                completions: newCompletions
            )
        }
    }

    private func finishCachedTitleExport(
        _ url: URL,
        saveToPhotos: Bool,
        completion: ((URL?) -> Void)?
    ) {
        guard saveToPhotos, !completedTitleExportSavedToPhotos else {
            completion?(url)
            return
        }

        isExporting = true
        statusMessage = "Saving your Wrap…"
        ScreenWakeLock.setActive(true)
        Task { @MainActor in
            await saveToPhotosIfPossible(videoURL: url)
            completedTitleExportSavedToPhotos = savedToPhotos
            isExporting = false
            statusMessage = nil
            ScreenWakeLock.release()
            completion?(url)
        }
    }

    private func startTitleExport(
        _ title: String,
        durationSeconds: TimeInterval,
        saveToPhotos: Bool,
        completions: [(URL?) -> Void]
    ) {
        guard let raw = retainedRawURL, lastExportFrameCount > 0 else {
            completions.forEach { $0(finalVideoURL) }
            return
        }

        isExporting = true
        activeTitleExportTitle = title
        activeTitleExportCompletions = completions
        activeTitleExportShouldSaveToPhotos = saveToPhotos
        statusMessage = "Generating your Wrap…"
        ScreenWakeLock.setActive(true)
        // Prefer the session's actual duration; fall back to the recorded wall-clock.
        let secs = durationSeconds > 0 ? durationSeconds : recordedWallClockSeconds
        exportEngine.generateWrappedVideo(
            rawVideoURL: raw,
            capturedFrameCount: lastExportFrameCount,
            overlay: makeOverlay(durationSeconds: secs, title: title)
        ) { [weak self] finalURL in
            Task { @MainActor in
                guard let self else { return }
                let finishedTitle = self.activeTitleExportTitle
                let callbacks = self.activeTitleExportCompletions
                let shouldSaveToPhotos = self.activeTitleExportShouldSaveToPhotos
                self.activeTitleExportTitle = nil
                self.activeTitleExportCompletions.removeAll()
                self.activeTitleExportShouldSaveToPhotos = false
                self.isExporting = false
                self.statusMessage = nil
                if let finalURL {
                    // Every re-title renders a fresh file in the finals dir — drop the
                    // one it replaces so title edits don't pile up orphaned videos.
                    if let old = self.finalVideoURL, old != finalURL {
                        try? FileManager.default.removeItem(at: old)
                    }
                    self.finalVideoURL = finalURL
                    if self.previewFrames.isEmpty {
                        self.previewFrames = Self.extractPreviewFrames(from: finalURL, count: 3)
                    }
                    self.completedTitleExportTitle = finishedTitle
                    self.completedTitleExportSavedToPhotos = false
                    if shouldSaveToPhotos {
                        await self.saveToPhotosIfPossible(videoURL: finalURL)
                        self.completedTitleExportSavedToPhotos = self.savedToPhotos
                    }
                } else {
                    self.lastError = "Could not stitch session video."
                }
                ScreenWakeLock.release()
                callbacks.forEach { $0(finalURL) }

                let pending = self.pendingTitleExport
                self.pendingTitleExport = nil
                if let pending {
                    if let finalVideoURL = self.finalVideoURL,
                       self.completedTitleExportTitle == pending.title {
                        self.finishCachedTitleExport(
                            finalVideoURL,
                            saveToPhotos: pending.saveToPhotos,
                            completion: { url in
                                pending.completions.forEach { $0(url) }
                            }
                        )
                    } else {
                        self.startTitleExport(
                            pending.title,
                            durationSeconds: pending.durationSeconds,
                            saveToPhotos: pending.saveToPhotos,
                            completions: pending.completions
                        )
                    }
                }
            }
        }
    }
}
