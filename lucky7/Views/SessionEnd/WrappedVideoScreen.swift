//
//  WrappedVideoScreen.swift
//  lucky7
//

import SwiftUI
import SwiftData
import AVKit

struct WrappedVideoScreen: View {
    var sessionId: UUID
    var videoFrames: [UIImage] = []

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionRecording: SessionRecordingViewModel

    @Query private var sessions: [Session]
    @State private var player: AVPlayer?
    @State private var isPlaying = true

    init(sessionId: UUID, videoFrames: [UIImage] = []) {
        self.sessionId = sessionId
        self.videoFrames = videoFrames
        _sessions = Query(filter: #Predicate<Session> { $0.id == sessionId })
    }

    // MARK: - Derived data

    private var session: Session? { sessions.first }

    private var displayTitle: String {
        let t = session?.title ?? ""
        return t.isEmpty ? "Untitled session" : t
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private var durationText: String {
        formatDuration(session?.actualDuration ?? 0)
    }

    private var dateText: String {
        guard let start = session?.startTime else { return "" }
        return start
            .formatted(.dateTime.day().month(.abbreviated).year())
            .uppercased()
    }

    private var videoURL: URL? {
        if let path = session?.wrappedVideoPath {
            return URL(fileURLWithPath: path)
        }
        return sessionRecording.finalVideoURL
    }

    private var shareableVideoURL: URL? { videoURL }

    private var shareableText: String {
        "\(displayTitle) — \(durationText) on \(dateText)"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color("CanvasBlue")
                .ignoresSafeArea()

            Image("PatternBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .offset(y: -30)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                mediaCard
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)

                playPauseButton
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if let videoURL {
                player = AVPlayer(url: videoURL)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            shareButton
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let videoURL = shareableVideoURL {
            ShareLink(item: videoURL, preview: SharePreview(displayTitle)) {
                shareIcon
            }
        } else {
            ShareLink(item: shareableText, preview: SharePreview(displayTitle)) {
                shareIcon
            }
        }
    }

    private var shareIcon: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
            .padding(12)
            .background(Circle().fill(Color.white))
            .overlay(Circle().stroke(Color.black, lineWidth: 2))
    }

    private var mediaCard: some View {
        ZStack(alignment: .top) {
            Group {
                if let player {
                    VideoPlayer(player: player)
                } else if let firstFrame = videoFrames.first {
                    Image(uiImage: firstFrame)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray.opacity(0.8)
                        .overlay(
                            Image(systemName: "person.crop.rectangle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white.opacity(0.5))
                                .padding(50)
                        )
                }
            }
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.black)
                    .offset(x: 0, y: 5)
            )
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.4), .clear, .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: 32))
            )

            mediaOverlay
        }
    }

    private var mediaOverlay: some View {
        VStack(spacing: 4) {
            Text(displayTitle)
                .font(.custom("Special Gothic Expanded One", size: 16))
                .multilineTextAlignment(.center)

            Text(durationText)
                .font(.custom("Special Gothic Expanded One", size: 50))
                .tracking(-1.5)

            Text(dateText)
                .font(.system(size: 12, weight: .bold))
                .kerning(1.5)
                .opacity(0.8)
        }
        .foregroundColor(.white)
        .padding(.top, 40)
        .padding(.horizontal, 16)
    }

    private var playPauseButton: some View {
        Button(action: togglePlayback) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.black)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(Color.black, lineWidth: 3))
        }
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

#Preview {
    WrappedVideoScreen(sessionId: UUID(), videoFrames: [])
        .environmentObject(SessionRecordingViewModel())
        .modelContainer(for: Session.self, inMemory: true)
}
