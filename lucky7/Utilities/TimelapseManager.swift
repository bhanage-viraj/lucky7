//
//  TimelapseManager.swift
//  lucky7
//
//  Spreads up to 1800 frames evenly across the planned session.
//  Stops early → fewer frames → shorter video (e.g. half session → 900 frames → 15s @ 60fps).
//

import AVFoundation
import UIKit

struct TimelapseStopResult {
    let url: URL?
    let frameCount: Int
}

final class TimelapseManager: NSObject {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.lucky7.timelapse.session")
    private let writerQueue = DispatchQueue(label: "com.lucky7.timelapse.writer")

    private var videoOutput: AVCaptureVideoDataOutput?
    private var assetWriter: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var cameraFrameIndex = 0
    private var framesCaptured = 0
    private var plannedSessionSeconds: TimeInterval = 3600
    private var captureIntervalSeconds: TimeInterval = 2
    private var isRecording = false
    var capturePaused = false
    private var isWriterReady = false
    private var hasWrittenFrame = false
    private var recordingStartWallSeconds: Double?
    private var totalPausedSeconds: Double = 0
    private var pauseBeganWallSeconds: Double?

    private(set) var outputURL: URL?
    private(set) var lastCapturedFrameCount = 0
    /// Frames captured in the current or most recent recording session.
    var currentFrameCount: Int { framesCaptured }

    var captureSession: AVCaptureSession { session }

    // MARK: - Setup

    func requestPermissionAndConfigure(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Already configured? Just make sure it's running. prepareCamera() fires on
            // every return to foreground — rebuilding here would glitch an in-flight
            // recording and snap a back-camera pick back to the front camera.
            sessionQueue.async {
                if self.session.inputs.isEmpty {
                    self.configureSession(position: .front, completion: completion)
                } else {
                    if !self.session.isRunning { self.session.startRunning() }
                    DispatchQueue.main.async { completion(true) }
                }
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.configureSession(position: .front, completion: completion)
                } else {
                    DispatchQueue.main.async { completion(false) }
                }
            }
        default:
            DispatchQueue.main.async { completion(false) }
        }
    }

    func switchCamera() {
        sessionQueue.async {
            let next: AVCaptureDevice.Position = self.currentPosition() == .front ? .back : .front
            self.configureSession(position: next, completion: nil)
        }
    }

    func startRunning() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopRunning() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Recording

    func beginPause() {
        writerQueue.async {
            guard self.pauseBeganWallSeconds == nil else { return }
            self.pauseBeganWallSeconds = self.currentWallElapsedSeconds()
        }
    }

    func endPause() {
        writerQueue.async {
            guard let began = self.pauseBeganWallSeconds else { return }
            let end = self.currentWallElapsedSeconds()
            self.totalPausedSeconds += max(0, end - began)
            self.pauseBeganWallSeconds = nil
        }
    }

    func startRecording(plannedSessionSeconds: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        sessionQueue.async {
            self.resetWriterState()
            self.plannedSessionSeconds = max(plannedSessionSeconds, AppConstants.minimumPlannedSessionSeconds)
            self.captureIntervalSeconds = AppConstants.captureIntervalSeconds(plannedSessionSeconds: self.plannedSessionSeconds)

            print(
                String(
                    format: "TimelapseManager: planned %.0fs → capture every %.2fs (up to %d frames = %.0fs video)",
                    self.plannedSessionSeconds,
                    self.captureIntervalSeconds,
                    AppConstants.maxFramesForFullSession,
                    AppConstants.maxWrappedDurationSeconds
                )
            )

            self.outputURL = Self.makeOutputURL(suffix: "raw")
            guard self.outputURL != nil else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            do {
                let writer = try AVAssetWriter(outputURL: self.outputURL!, fileType: .mp4)
                self.assetWriter = writer
                self.isRecording = true
                DispatchQueue.main.async { completion?(true) }
            } catch {
                print("TimelapseManager: failed to create writer – \(error)")
                self.isRecording = false
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    func stopRecording(completion: @escaping (TimelapseStopResult) -> Void) {
        sessionQueue.async {
            guard self.isRecording else {
                DispatchQueue.main.async {
                    completion(TimelapseStopResult(url: nil, frameCount: 0))
                }
                return
            }

            self.isRecording = false
            let captured = self.framesCaptured

            guard let writer = self.assetWriter, self.isWriterReady, self.hasWrittenFrame, captured > 0 else {
                print("TimelapseManager: no frames captured")
                if let url = self.outputURL {
                    try? FileManager.default.removeItem(at: url)
                }
                self.resetWriterState()
                DispatchQueue.main.async {
                    completion(TimelapseStopResult(url: nil, frameCount: 0))
                }
                return
            }

            self.writerInput?.markAsFinished()

            writer.finishWriting {
                let success = writer.status == .completed
                let url = success ? self.outputURL : nil
                let duration = AppConstants.wrappedDurationSeconds(frameCount: captured)
                if success {
                    print(
                        String(
                            format: "TimelapseManager: %d frames → %.1fs video @ %.0ffps",
                            captured,
                            duration,
                            AppConstants.wrappedOutputFPS
                        )
                    )
                } else {
                    print("TimelapseManager: finishWriting failed – \(writer.error?.localizedDescription ?? "unknown")")
                }
                self.lastCapturedFrameCount = captured
                self.resetWriterState()
                DispatchQueue.main.async {
                    completion(TimelapseStopResult(url: url, frameCount: captured))
                }
            }
        }
    }

    // MARK: - Private

    private func configureSession(position: AVCaptureDevice.Position, completion: ((Bool) -> Void)?) {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            for input in self.session.inputs { self.session.removeInput(input) }
            for output in self.session.outputs { self.session.removeOutput(output) }

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { completion?(false) }
                return
            }

            self.session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.writerQueue)

            guard self.session.canAddOutput(output) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { completion?(false) }
                return
            }

            self.session.addOutput(output)
            self.videoOutput = output

            // Keep sample buffers in sensor orientation; AVAssetWriterInput.transform
            // sets the correct portrait/landscape metadata on the saved file.
            if let connection = output.connection(with: .video) {
                let angle: CGFloat = 0
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            }

            self.session.commitConfiguration()

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async { completion?(true) }
        }
    }

    private func currentPosition() -> AVCaptureDevice.Position {
        guard let input = session.inputs.first as? AVCaptureDeviceInput else { return .front }
        return input.device.position
    }

    private func resetWriterState() {
        assetWriter = nil
        writerInput = nil
        pixelBufferAdaptor = nil
        isWriterReady = false
        hasWrittenFrame = false
        cameraFrameIndex = 0
        framesCaptured = 0
        recordingStartWallSeconds = nil
        totalPausedSeconds = 0
        pauseBeganWallSeconds = nil
    }

    private static func makeOutputURL(suffix: String) -> URL? {
        let name = "timelapse_\(suffix)_\(UUID().uuidString).mp4"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private func currentWallElapsedSeconds(now: Double = ProcessInfo.processInfo.systemUptime) -> Double {
        guard let start = recordingStartWallSeconds else { return 0 }
        return max(0, now - start - totalPausedSeconds)
    }

    private func shouldCaptureFrame(wallElapsed: Double) -> Bool {
        guard framesCaptured < AppConstants.maxFramesForFullSession else { return false }
        if framesCaptured == 0 { return true }
        let nextCaptureAt = Double(framesCaptured) * captureIntervalSeconds
        return wallElapsed + 0.001 >= nextCaptureAt
    }

    private func outputPresentationTime(forFrameIndex index: Int) -> CMTime {
        CMTime(value: CMTimeValue(index), timescale: CMTimeScale(AppConstants.wrappedOutputFPS))
    }

    private func setupWriterIfNeeded(from sampleBuffer: CMSampleBuffer) async -> Bool {
        guard let writer = assetWriter, writer.status == .unknown else {
            return isWriterReady
        }

        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return false }

        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let width = Int(dimensions.width)
        let height = Int(dimensions.height)
        guard width > 0, height > 0 else { return false }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        input.transform = await VideoOrientationHelper.writerTransform(
            bufferWidth: width,
            bufferHeight: height,
            cameraPosition: currentPosition()
        )

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        guard writer.canAdd(input) else { return false }

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        writerInput = input
        pixelBufferAdaptor = adaptor
        isWriterReady = true
        recordingStartWallSeconds = ProcessInfo.processInfo.systemUptime
        return true
    }

    private func appendFrame(from sampleBuffer: CMSampleBuffer) async {
        guard isRecording, !capturePaused, let writer = assetWriter else { return }
        guard writer.status != .failed else { return }

        cameraFrameIndex += 1
        if !isWriterReady {
            guard await setupWriterIfNeeded(from: sampleBuffer) else { return }
        }

        guard writer.status == .writing,
              let input = writerInput,
              input.isReadyForMoreMediaData,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let wallElapsed = currentWallElapsedSeconds()
        guard shouldCaptureFrame(wallElapsed: wallElapsed) else { return }

        let presentationTime = outputPresentationTime(forFrameIndex: framesCaptured)

        guard pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: presentationTime) == true else {
            print("TimelapseManager: failed to append frame \(framesCaptured)")
            return
        }

        framesCaptured += 1
        hasWrittenFrame = true
    }
}

extension TimelapseManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        Task { [weak self] in
            await self?.appendFrame(from: sampleBuffer)
        }
    }
}
