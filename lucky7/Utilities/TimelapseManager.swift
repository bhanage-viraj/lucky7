//
//  TimelapseManager.swift
//  lucky7
//

import AVFoundation
import UIKit

final class TimelapseManager: NSObject {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.lucky7.timelapse.session")
    private let writerQueue = DispatchQueue(label: "com.lucky7.timelapse.writer")

    private var videoOutput: AVCaptureVideoDataOutput?
    private var assetWriter: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var frameIndex = 0
    /// Keep ~1 frame per second at 30fps so short sessions still produce a file.
    private let frameSkip = 30
    private var isRecording = false
    var capturePaused = false
    private var isWriterReady = false
    private var hasWrittenFrame = false
    private var recordingStartTime: CMTime?
    private var lastPresentationTime: CMTime = .zero

    private(set) var outputURL: URL?

    var captureSession: AVCaptureSession { session }

    // MARK: - Setup

    func requestPermissionAndConfigure(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession(position: .front, completion: completion)
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

    func configureSampling(forPlannedSessionSeconds: TimeInterval) {
        // Export always outputs 30s; capture keeps ~1 frame/sec regardless of planned length.
        print("TimelapseManager: planned \(Int(forPlannedSessionSeconds))s session, capturing 1 frame every \(frameSkip) camera frames")
    }

    func startRecording(completion: ((Bool) -> Void)? = nil) {
        sessionQueue.async {
            self.resetWriterState()
            self.outputURL = Self.makeOutputURL(suffix: "raw")
            guard self.outputURL != nil else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            do {
                let writer = try AVAssetWriter(outputURL: self.outputURL!, fileType: .mp4)
                self.assetWriter = writer
                self.isRecording = true
                self.frameIndex = 0
                self.recordingStartTime = nil
                self.lastPresentationTime = .zero
                print("TimelapseManager: recording started")
                DispatchQueue.main.async { completion?(true) }
            } catch {
                print("TimelapseManager: failed to create writer – \(error)")
                self.isRecording = false
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        sessionQueue.async {
            guard self.isRecording else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.isRecording = false

            guard let writer = self.assetWriter, self.isWriterReady, self.hasWrittenFrame else {
                print("TimelapseManager: no frames captured")
                if let url = self.outputURL {
                    try? FileManager.default.removeItem(at: url)
                }
                self.resetWriterState()
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.writerInput?.markAsFinished()

            writer.finishWriting { [weak self] in
                guard let self else { return }
                let success = writer.status == .completed
                let url = success ? self.outputURL : nil
                if !success {
                    print("TimelapseManager: finishWriting failed – \(writer.error?.localizedDescription ?? "unknown")")
                } else {
                    print("TimelapseManager: raw video saved at \(url?.lastPathComponent ?? "")")
                }
                self.resetWriterState()
                DispatchQueue.main.async { completion(url) }
            }
        }
    }

    // MARK: - Private

    private func configureSession(position: AVCaptureDevice.Position, completion: ((Bool) -> Void)?) {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            for output in self.session.outputs {
                self.session.removeOutput(output)
            }

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

            if let connection = output.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                } else if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
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
        frameIndex = 0
        recordingStartTime = nil
        lastPresentationTime = .zero
    }

    private static func makeOutputURL(suffix: String) -> URL? {
        let name = "timelapse_\(suffix)_\(UUID().uuidString).mp4"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private func setupWriterIfNeeded(from sampleBuffer: CMSampleBuffer) -> Bool {
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
        recordingStartTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        return true
    }

    private func shouldKeepFrame() -> Bool {
        frameIndex += 1
        // Always keep the first good frame so very short sessions still export.
        if frameIndex == 1 { return true }
        return frameIndex % frameSkip == 0
    }

    private func appendFrame(from sampleBuffer: CMSampleBuffer) {
        guard isRecording, !capturePaused, let writer = assetWriter else { return }
        guard writer.status != .failed else { return }

        if !isWriterReady {
            guard setupWriterIfNeeded(from: sampleBuffer) else { return }
        }

        guard writer.status == .writing,
              let input = writerInput,
              input.isReadyForMoreMediaData,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        guard shouldKeepFrame() else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let start = recordingStartTime ?? timestamp
        var presentationTime = CMTimeSubtract(timestamp, start)
        if presentationTime <= lastPresentationTime {
            presentationTime = CMTimeAdd(lastPresentationTime, CMTime(value: 1, timescale: 30))
        }

        guard pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: presentationTime) == true else {
            print("TimelapseManager: failed to append frame")
            return
        }

        hasWrittenFrame = true
        lastPresentationTime = presentationTime
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension TimelapseManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        appendFrame(from: sampleBuffer)
    }
}
