//
//  WrappedVideoScreen.swift
//  lucky7
//

import SwiftUI
import SwiftData
import AVKit

struct WrappedVideoScreen: View {
    let kind: Kind
    var videoFrames: [UIImage] = []

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionRecording: SessionRecordingViewModel

    @Query private var sessions: [Session]
    @State private var player: AVPlayer?
    @State private var isPlaying = true

    init(kind: Kind, videoFrames: [UIImage] = []) {
        self.kind = kind
        self.videoFrames = videoFrames
        // Only the session wrap is backed by a real record. Weekly/monthly wraps
        // aren't generated yet, so their query intentionally matches nothing.
        let sessionId: UUID
        if case .session(let id) = kind { sessionId = id } else { sessionId = UUID() }
        _sessions = Query(filter: #Predicate<Session> { $0.id == sessionId })
    }

    // MARK: - Derived data

    private var session: Session? { sessions.first }

    /// Weekly and monthly wraps don't have generated videos yet, so they show a
    /// "coming soon" placeholder rather than a playable timelapse.
    private var isWrapReady: Bool {
        if case .session = kind { return true }
        return false
    }

    private var displayTitle: String {
        switch kind {
        case .session:
            let t = session?.title ?? ""
            return t.isEmpty ? "Untitled session" : t
        case .weekly(let title, _, _), .monthly(let title, _, _):
            return title
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private var durationText: String {
        switch kind {
        case .session:
            return formatDuration(session?.actualDuration ?? 0)
        case .weekly(_, _, let duration), .monthly(_, _, let duration):
            return formatDuration(duration)
        }
    }

    private var dateText: String {
        switch kind {
        case .session:
            guard let start = session?.startTime else { return "" }
            return start
                .formatted(.dateTime.day().month(.abbreviated).year())
                .uppercased()
        case .weekly(_, let periodLabel, _), .monthly(_, let periodLabel, _):
            return periodLabel.uppercased()
        }
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
            // The title / duration / date are already burned into the wrap video,
            // so we no longer overlay them again here.
        }
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
        .disabled(!isWrapReady)
        .opacity(isWrapReady ? 1 : 0.5)
    }
}

extension WrappedVideoScreen {
    /// The three sources a wrap can be built from. Only `.session` is backed by real
    /// data today; `.weekly` and `.monthly` carry display info but show a placeholder.
    enum Kind {
        case session(UUID)
        case weekly(title: String, periodLabel: String, duration: TimeInterval)
        case monthly(title: String, periodLabel: String, duration: TimeInterval)
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
    WrappedVideoScreen(kind: .session(UUID()), videoFrames: [])
        .environmentObject(SessionRecordingViewModel())
        .modelContainer(for: Session.self, inMemory: true)
}
