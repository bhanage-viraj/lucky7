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
    @Published var previewFrames: [UIImage] = []
    @Published var cameraReady = false
    @Published var permissionDenied = false
    @Published var savedToPhotos = false
    @Published var lastError: String?
    @Published var statusMessage: String?

    private let timelapseManager = TimelapseManager()
    private let exportEngine = ExportEngine.shared
    private var plannedSessionSeconds: TimeInterval = 0
    private var recordedWallClockSeconds: TimeInterval = 0
    private var didCaptureThisSession = false
    private var exportCompletions: [() -> Void] = []

    var captureSession: AVCaptureSession {
        timelapseManager.captureSession
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
        statusMessage = "Recording…"
        self.plannedSessionSeconds = max(plannedSessionSeconds, 60)
        recordedWallClockSeconds = 0

        timelapseManager.configureSampling(forPlannedSessionSeconds: self.plannedSessionSeconds)
        timelapseManager.startRecording { [weak self] started in
            Task { @MainActor in
                guard let self else { return }
                if started {
                    self.isRecording = true
                    self.didCaptureThisSession = true
                } else {
                    self.lastError = "Could not start recording."
                    self.statusMessage = nil
                }
            }
        }
    }

    func pauseRecording() {
        timelapseManager.capturePaused = true
        statusMessage = "Recording paused"
    }

    func resumeRecording() {
        timelapseManager.capturePaused = false
        statusMessage = "Recording…"
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
        statusMessage = "Saving your session video…"

        timelapseManager.stopRecording { [weak self] rawURL in
            Task { @MainActor in
                guard let self else { return }

                guard let rawURL else {
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

                self.exportEngine.generateWrappedVideo(
                    rawVideoURL: rawURL,
                    sessionWallClockSeconds: wallClock > 0 ? wallClock : nil,
                    maxTargetDurationInSeconds: AppConstants.wrappedVideoDurationSeconds
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

                        await self.saveToPhotosIfPossible(videoURL: finalURL)
                        self.finishExportCompletions()
                    }
                }
            }
        }
    }

    private func finishExportCompletions() {
        let completions = exportCompletions
        exportCompletions.removeAll()
        completions.forEach { $0() }
    }

    func resetForNewSession() {
        isRecording = false
        isExporting = false
        finalVideoURL = nil
        previewFrames = []
        lastError = nil
        savedToPhotos = false
        statusMessage = nil
        plannedSessionSeconds = 0
        recordedWallClockSeconds = 0
        didCaptureThisSession = false
        exportCompletions.removeAll()
        timelapseManager.capturePaused = false
    }

    var wrappedDurationSeconds: TimeInterval {
        AppConstants.wrappedVideoDurationSeconds
    }

    // MARK: - Private

    private func saveToPhotosIfPossible(videoURL: URL) async {
        do {
            try await PhotoLibrarySaver.saveVideo(at: videoURL)
            savedToPhotos = true
            statusMessage = "Saved to Photos"
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
}
