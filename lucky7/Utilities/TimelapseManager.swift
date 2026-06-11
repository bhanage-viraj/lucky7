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
    private lazy var sampleBufferDelegate = TimelapseSampleBufferDelegate { [weak self] sampleBuffer in
        self?.appendFrame(from: sampleBuffer)
    }

    private var cameraFrameIndex = 0
    private var framesCaptured = 0
    private var plannedSessionSeconds: TimeInterval = 3600
    private var captureIntervalSeconds: TimeInterval = 2
    private var isRecording = false
    private var capturePaused = false
    private var isWriterReady = false
    private var hasWrittenFrame = false
    private var recordingStartWallSeconds: Double?
    private var totalPausedSeconds: Double = 0
    private var pauseBeganWallSeconds: Double?
    private var configuredPosition: AVCaptureDevice.Position = .front
    private var sampleBuffersReceived = 0
    private var loggedNotRecordingDrop = false
    private var loggedPausedDrop = false
    private var loggedMissingWriterDrop = false

    private(set) var outputURL: URL?
    private(set) var lastCapturedFrameCount = 0
    /// Frames captured in the current or most recent recording session.
    var currentFrameCount: Int { framesCaptured }

    var captureSession: AVCaptureSession { session }

    // MARK: - Setup

    func requestPermissionAndConfigure(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            log("camera permission authorized")
            // Already configured? Just make sure it's running. prepareCamera() fires on
            // every return to foreground — rebuilding here would glitch an in-flight
            // recording and snap a back-camera pick back to the front camera.
            sessionQueue.async {
                if self.session.inputs.isEmpty {
                    self.log("configuring camera: no existing input")
                    self.configureSession(position: .front, completion: completion)
                } else {
                    if !self.session.isRunning { self.session.startRunning() }
                    self.log("camera already configured inputs=\(self.session.inputs.count) outputs=\(self.session.outputs.count) running=\(self.session.isRunning)")
                    DispatchQueue.main.async { completion(true) }
                }
            }
        case .notDetermined:
            log("camera permission not determined; requesting")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                self.log("camera permission request result granted=\(granted)")
                if granted {
                    self.configureSession(position: .front, completion: completion)
                } else {
                    DispatchQueue.main.async { completion(false) }
                }
            }
        default:
            log("camera permission denied/restricted status=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue)")
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
            self.log("camera startRunning running=\(self.session.isRunning)")
        }
    }

    func restartRunning() {
        sessionQueue.async {
            self.log("camera restart requested runningBefore=\(self.session.isRunning)")
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.session.startRunning()
            self.log("camera restart finished running=\(self.session.isRunning)")
        }
    }

    func stopRunning() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Recording

    func pauseCapture() {
        writerQueue.async {
            self.capturePaused = true
            self.log("capture paused framesCaptured=\(self.framesCaptured) samples=\(self.sampleBuffersReceived)")
            guard self.pauseBeganWallSeconds == nil else { return }
            self.pauseBeganWallSeconds = self.currentWallElapsedSeconds()
        }
    }

    func resumeCapture() {
        writerQueue.async {
            if let began = self.pauseBeganWallSeconds {
                let end = self.currentWallElapsedSeconds()
                self.totalPausedSeconds += max(0, end - began)
                self.pauseBeganWallSeconds = nil
            }
            self.capturePaused = false
            self.log("capture resumed framesCaptured=\(self.framesCaptured) samples=\(self.sampleBuffersReceived)")
        }
    }

    func resetCapturePause() {
        writerQueue.async {
            self.capturePaused = false
            self.pauseBeganWallSeconds = nil
            self.log("capture pause reset")
        }
    }

    func startRecording(plannedSessionSeconds: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        writerQueue.async {
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
                self.log("startRecording failed: output URL nil")
                DispatchQueue.main.async { completion?(false) }
                return
            }

            do {
                let writer = try AVAssetWriter(outputURL: self.outputURL!, fileType: .mp4)
                self.assetWriter = writer
                self.isRecording = true
                self.startRunning()
                self.log("startRecording ok raw=\(self.outputURL!.lastPathComponent) interval=\(String(format: "%.3f", self.captureIntervalSeconds))")
                DispatchQueue.main.async { completion?(true) }
            } catch {
                self.log("startRecording failed writer error=\(error.localizedDescription)")
                self.isRecording = false
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    func stopRecording(completion: @escaping (TimelapseStopResult) -> Void) {
        let waitUntil = DispatchTime.now() + .milliseconds(1200)
        writerQueue.async {
            self.finishRecording(waitUntil: waitUntil, completion: completion)
        }
    }

    private func finishRecording(
        waitUntil: DispatchTime,
        completion: @escaping (TimelapseStopResult) -> Void
    ) {
        guard self.isRecording else {
            DispatchQueue.main.async {
                completion(TimelapseStopResult(url: nil, frameCount: 0))
            }
            return
        }

        var hasUsableFrame = self.isWriterReady && self.hasWrittenFrame && self.framesCaptured > 0
        if !hasUsableFrame, self.capturePaused {
            self.endPauseAccountingForStop()
            hasUsableFrame = self.isWriterReady && self.hasWrittenFrame && self.framesCaptured > 0
        }

        if !hasUsableFrame,
           DispatchTime.now().uptimeNanoseconds < waitUntil.uptimeNanoseconds {
            self.log("stop waiting for first usable frame samples=\(self.sampleBuffersReceived) writerReady=\(self.isWriterReady) hasFrame=\(self.hasWrittenFrame)")
            self.startRunning()
            self.writerQueue.asyncAfter(deadline: .now() + .milliseconds(150)) {
                self.finishRecording(waitUntil: waitUntil, completion: completion)
            }
            return
        }

        self.isRecording = false
        let captured = self.framesCaptured

        guard let writer = self.assetWriter, self.isWriterReady, self.hasWrittenFrame, captured > 0 else {
            self.log("stop failed no frames captured samples=\(self.sampleBuffersReceived) writerReady=\(self.isWriterReady) hasFrame=\(self.hasWrittenFrame) captured=\(captured)")
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
                self.log("finishWriting failed error=\(writer.error?.localizedDescription ?? "unknown") captured=\(captured)")
            }
            self.writerQueue.async {
                let exists = url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
                self.log("stop finished success=\(success) captured=\(captured) url=\(url?.lastPathComponent ?? "nil") exists=\(exists)")
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
                self.log("configure failed position=\(position.rawValue)")
                DispatchQueue.main.async { completion?(false) }
                return
            }

            self.session.addInput(input)
            self.configuredPosition = position

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self.sampleBufferDelegate, queue: self.writerQueue)

            guard self.session.canAddOutput(output) else {
                self.session.commitConfiguration()
                self.log("configure failed: cannot add output")
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

            self.log("configure success position=\(position.rawValue) inputs=\(self.session.inputs.count) outputs=\(self.session.outputs.count) running=\(self.session.isRunning)")
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
        sampleBuffersReceived = 0
        loggedNotRecordingDrop = false
        loggedPausedDrop = false
        loggedMissingWriterDrop = false
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

    private func endPauseAccountingForStop() {
        if let began = pauseBeganWallSeconds {
            let end = currentWallElapsedSeconds()
            totalPausedSeconds += max(0, end - began)
            pauseBeganWallSeconds = nil
        }
        capturePaused = false
        log("stop unpaused capture to flush final frame framesCaptured=\(framesCaptured) samples=\(sampleBuffersReceived)")
    }

    private func outputPresentationTime(forFrameIndex index: Int) -> CMTime {
        CMTime(value: CMTimeValue(index), timescale: CMTimeScale(AppConstants.wrappedOutputFPS))
    }

    private func setupWriterIfNeeded(from sampleBuffer: CMSampleBuffer) -> Bool {
        guard let writer = assetWriter, writer.status == .unknown else {
            return isWriterReady
        }

        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            log("setupWriter failed: no formatDescription")
            return false
        }

        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let width = Int(dimensions.width)
        let height = Int(dimensions.height)
        guard width > 0, height > 0 else {
            log("setupWriter failed: invalid dimensions \(width)x\(height)")
            return false
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        input.transform = VideoOrientationHelper.writerTransform(
            bufferWidth: width,
            bufferHeight: height,
            cameraPosition: configuredPosition,
            orientation: VideoOrientationHelper.currentInterfaceOrientationSync()
        )

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        guard writer.canAdd(input) else {
            log("setupWriter failed: writer cannot add input")
            return false
        }

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        writerInput = input
        pixelBufferAdaptor = adaptor
        isWriterReady = true
        recordingStartWallSeconds = ProcessInfo.processInfo.systemUptime
        log("setupWriter ok dimensions=\(width)x\(height) camera=\(configuredPosition.rawValue)")
        return true
    }

    private func appendFrame(from sampleBuffer: CMSampleBuffer) {
        sampleBuffersReceived += 1
        if sampleBuffersReceived <= 3 {
            log("sample received #\(sampleBuffersReceived) isRecording=\(isRecording) paused=\(capturePaused) writerNil=\(assetWriter == nil)")
        }

        guard isRecording else {
            if !loggedNotRecordingDrop {
                loggedNotRecordingDrop = true
                log("sample dropped: not recording")
            }
            return
        }
        guard !capturePaused else {
            if !loggedPausedDrop {
                loggedPausedDrop = true
                log("sample dropped: paused")
            }
            return
        }
        guard let writer = assetWriter else {
            if !loggedMissingWriterDrop {
                loggedMissingWriterDrop = true
                log("sample dropped: missing writer")
            }
            return
        }
        guard writer.status != .failed else {
            log("sample dropped: writer failed error=\(writer.error?.localizedDescription ?? "unknown")")
            return
        }

        cameraFrameIndex += 1
        if !isWriterReady {
            guard setupWriterIfNeeded(from: sampleBuffer) else { return }
        }

        guard writer.status == .writing,
              let input = writerInput,
              input.isReadyForMoreMediaData,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let wallElapsed = currentWallElapsedSeconds()
        guard shouldCaptureFrame(wallElapsed: wallElapsed) else { return }

        let presentationTime = outputPresentationTime(forFrameIndex: framesCaptured)

        guard pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: presentationTime) == true else {
            log("append failed frame=\(framesCaptured) writerStatus=\(writer.status.rawValue) inputReady=\(input.isReadyForMoreMediaData)")
            return
        }

        framesCaptured += 1
        hasWrittenFrame = true
        if framesCaptured <= 3 || framesCaptured == 10 || framesCaptured % 60 == 0 {
            log("frame appended captured=\(framesCaptured) samples=\(sampleBuffersReceived)")
        }
    }

    private func log(_ message: String) {
        RecordingDiagnostics.log("Timelapse \(message)")
    }
}

private final class TimelapseSampleBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated(unsafe) private let onSampleBuffer: (CMSampleBuffer) -> Void

    init(onSampleBuffer: @escaping (CMSampleBuffer) -> Void) {
        self.onSampleBuffer = onSampleBuffer
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onSampleBuffer(sampleBuffer)
    }
}
