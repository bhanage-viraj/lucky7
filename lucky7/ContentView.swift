import SwiftUI
import PhotosUI
import AVFoundation
import Combine
import UIKit // Added for UIFont and UIColor in CATextLayer

struct ContentView: View {
    @StateObject var processor = VideoProcessor()
    
    // Photos Picker state
    @State private var selectedItem: PhotosPickerItem? = nil
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Video Text Overlay Test")
                .font(.headline)
            
            // 1. Pick a video
            PhotosPicker(selection: $selectedItem, matching: .videos) {
                Label("Select Timelapse Video", systemImage: "photo.video")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .onChange(of: selectedItem) { newItem in
                processSelectedVideo(item: newItem)
            }
            
            // 2. Status Output
            if processor.isExporting {
                ProgressView("Rendering Video (This takes longer on Simulator)...")
                    .padding()
            }
            
            Text(processor.exportMessage)
                .multilineTextAlignment(.center)
                .padding()
                .font(.caption)
        }
        .padding()
    }
    
    // Helper to extract the URL from the PhotosPicker and run the test
    private func processSelectedVideo(item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            do {
                if let videoFile = try await item.loadTransferable(type: VideoFile.self) {
                    // Generate a unique output URL
                    let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("final_export_\(UUID().uuidString).mp4")

                    // Run the text overlay
                    await processor.addTextToVideo(inputURL: videoFile.url, outputURL: outputURL, text: "HELLO FROM SWIFT")
                } else {
                    await MainActor.run { processor.exportMessage = "Failed to load video file." }
                }
            } catch {
                await MainActor.run { processor.exportMessage = "Error: \(error.localizedDescription)" }
            }
        }
    }
}

// A helper struct to extract the URL from the PhotosPicker
struct VideoFile: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            VideoFile(url: movie.file)
        } importTransferRepresentation: { received in
            // Copy the file to a temporary location so we can work with it
            let copy = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(received.file.lastPathComponent)
            if FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return VideoFile(url: copy)
        }
    }
}

final class VideoProcessor: ObservableObject {
    @MainActor @Published var isExporting: Bool = false
    @MainActor @Published var exportMessage: String = "Pick a video to begin."

    /// Adds a text overlay to a video using AVFoundation and exports it.
    func addTextToVideo(inputURL: URL, outputURL: URL, text: String) async {
        await MainActor.run {
            self.isExporting = true
            self.exportMessage = "Preparing to render…"
        }

        let asset = AVURLAsset(url: inputURL)

        do {
            // 1. Load Tracks asynchronously
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw NSError(domain: "VideoProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
            }
            let audioTrack = try await asset.loadTracks(withMediaType: .audio).first

            // 2. Create AVMutableComposition
            let composition = AVMutableComposition()
            guard let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw NSError(domain: "VideoProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to add video track"])
            }

            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            try compVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)

            // Add audio if it exists
            if let audioTrack = audioTrack, let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try compAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            }

            // 3. Handle Orientation and Sizing
            let transform = try await videoTrack.load(.preferredTransform)
            let naturalSize = try await videoTrack.load(.naturalSize)
            
            // Check if video is portrait to adjust the render size
            let isPortrait = transform.a == 0 && transform.d == 0 && (transform.b == 1.0 || transform.b == -1.0)
            let renderSize = isPortrait ? CGSize(width: naturalSize.height, height: naturalSize.width) : naturalSize

            // 4. Set up Core Animation Layers
            let videoLayer = CALayer()
            videoLayer.frame = CGRect(origin: .zero, size: renderSize)
            
            let parentLayer = CALayer()
            parentLayer.frame = CGRect(origin: .zero, size: renderSize)
            parentLayer.addSublayer(videoLayer)

            // Setup Text Layer
            let textLayer = CATextLayer()
            textLayer.string = text
            textLayer.font = UIFont.boldSystemFont(ofSize: 60)
            textLayer.fontSize = 60
            textLayer.alignmentMode = .center
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
            textLayer.frame = CGRect(x: 0, y: 50, width: renderSize.width, height: 100) // Positioned slightly above the bottom/top
            textLayer.displayIfNeeded()
            
            parentLayer.addSublayer(textLayer)

            // 5. Create Video Composition
            let videoComp = AVMutableVideoComposition()
            videoComp.renderSize = renderSize
            videoComp.frameDuration = CMTime(value: 1, timescale: 30) // 30 FPS
            videoComp.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)

            // 6. Apply Transforms
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = timeRange
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
            layerInstruction.setTransform(transform, at: .zero)
            
            instruction.layerInstructions = [layerInstruction]
            videoComp.instructions = [instruction]

            // 7. Setup Export Session
            guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                throw NSError(domain: "VideoProcessor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
            }

            exportSession.videoComposition = videoComp
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4

            // Cleanup any existing file at the output URL
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            // 8. Execute Export
            await exportSession.export()

            await MainActor.run {
                switch exportSession.status {
                case .completed:
                    self.exportMessage = "Export complete!\nLocation: \(outputURL.path)"
                case .failed:
                    let errorMsg = exportSession.error?.localizedDescription ?? "Unknown error"
                    self.exportMessage = "Export failed: \(errorMsg)"
                case .cancelled:
                    self.exportMessage = "Export cancelled"
                default:
                    self.exportMessage = "Export stopped with status: \(exportSession.status.rawValue)"
                }
                self.isExporting = false
            }

        } catch {
            await MainActor.run {
                self.exportMessage = "Error: \(error.localizedDescription)"
                self.isExporting = false
            }
        }
    }
}
