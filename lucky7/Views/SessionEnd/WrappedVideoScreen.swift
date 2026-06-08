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
    @Query private var periodWraps: [PeriodWrap]
    @State private var player: AVPlayer?
    @State private var isPlaying = true
    @State private var didFinish = false

    init(kind: Kind, videoFrames: [UIImage] = []) {
        self.kind = kind
        self.videoFrames = videoFrames
        // Session wraps are backed by a `Session`; weekly/monthly by a `PeriodWrap`.
        let sessionId: UUID
        if case .session(let id) = kind { sessionId = id } else { sessionId = UUID() }
        _sessions = Query(filter: #Predicate<Session> { $0.id == sessionId })

        let key: String
        let kindStr: String
        switch kind {
        case .session:
            key = ""; kindStr = ""
        case .weekly(let k, _, _, _, _):
            key = k; kindStr = "weekly"
        case .monthly(let k, _, _, _, _):
            key = k; kindStr = "monthly"
        }
        _periodWraps = Query(filter: #Predicate<PeriodWrap> { $0.periodKey == key && $0.kind == kindStr })
    }

    // MARK: - Derived data

    private var session: Session? { sessions.first }
    private var periodWrap: PeriodWrap? { periodWraps.first }

    private var isWrapReady: Bool {
        switch kind {
        case .session: return true
        case .weekly, .monthly: return videoURL != nil
        }
    }

    /// Non-nil when a weekly/monthly wrap can't be shown yet — drives the warning modal.
    private var notReadyMessage: String? {
        switch kind {
        case .session:
            return nil
        case .weekly(_, let end, _, _, _):
            if Date() < end { return "Your weekly rewind will be ready once this week ends." }
            if periodWrap == nil { return "Your weekly rewind is still being put together — check back soon." }
            return nil
        case .monthly(_, let end, _, _, _):
            if Date() < end { return "Your monthly rewind will be ready once this month ends." }
            if periodWrap == nil { return "Your monthly rewind is still being put together — check back soon." }
            return nil
        }
    }

    private var displayTitle: String {
        switch kind {
        case .session:
            let t = session?.title ?? ""
            return t.isEmpty ? "Untitled session" : t
        case .weekly(_, _, let title, _, _), .monthly(_, _, let title, _, _):
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
        case .weekly(_, _, _, _, let duration), .monthly(_, _, _, _, let duration):
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
        case .weekly(_, _, _, let periodLabel, _), .monthly(_, _, _, let periodLabel, _):
            return periodLabel.uppercased()
        }
    }

    private var videoURL: URL? {
        switch kind {
        case .session:
            if let path = session?.wrappedVideoPath { return URL(fileURLWithPath: path) }
            return sessionRecording.finalVideoURL
        case .weekly, .monthly:
            if let path = periodWrap?.videoPath { return URL(fileURLWithPath: path) }
            return nil
        }
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

                Spacer(minLength: 16)

                mediaCard
                    .padding(.horizontal, 20)
                    .layoutPriority(1)

                Spacer(minLength: 16)

                playPauseButton
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .hidesFloatingTabBar()
        .overlay {
            if let message = notReadyMessage {
                WrapNotReadyModal(
                    title: "Not ready yet",
                    message: message,
                    onDismiss: { dismiss() }
                )
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { note in
            guard let item = note.object as? AVPlayerItem, item === player?.currentItem else { return }
            isPlaying = false
            didFinish = true
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
        .padding(.horizontal, 20)
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
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)
    }

    private var mediaCard: some View {
        // 9:16 portrait — matches the iPhone camera capture so the wrap video
        // fills the frame without letterbox bars.
        Color.clear
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .overlay {
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
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.black)
                    .offset(x: 0, y: 0)
            )
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.4), .clear, .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: 32))
            )
            .frame(maxWidth: 340)
    }

    private var playPauseButton: some View {
        Button(action: togglePlayback) {
            Image(systemName: didFinish ? "arrow.counterclockwise" : (isPlaying ? "pause.fill" : "play.fill"))
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.black))
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
        case weekly(periodKey: String, periodEnd: Date, title: String, periodLabel: String, duration: TimeInterval)
        case monthly(periodKey: String, periodEnd: Date, title: String, periodLabel: String, duration: TimeInterval)
    }

    private func togglePlayback() {
        guard let player else { return }
        // Finished → restart from the beginning.
        if didFinish {
            player.seek(to: .zero)
            player.play()
            isPlaying = true
            didFinish = false
            return
        }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

// MARK: - "Not ready yet" warning (EndSession-style bottom sheet)

private struct WrapNotReadyModal: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 38, height: 5)
                    .padding(.top, 10)

                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)

                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.top, 2)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.horizontal, 8)

                Button(action: onDismiss) {
                    Text("GOT IT")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 22)
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        }
    }
}

#Preview {
    WrappedVideoScreen(kind: .session(UUID()), videoFrames: [])
        .environmentObject(SessionRecordingViewModel())
        .modelContainer(for: [Session.self, PeriodWrap.self], inMemory: true)
}
