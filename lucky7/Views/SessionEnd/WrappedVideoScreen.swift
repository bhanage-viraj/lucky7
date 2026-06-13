//
//  WrappedVideoScreen.swift
//  lucky7
//

import SwiftUI
import SwiftData
import AVKit
import UniformTypeIdentifiers
import UIKit

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
    @State private var sharePayload: VideoSharePayload?

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
        videoURL != nil
    }

    /// The live flow's export is still rendering this wrap (nothing persisted yet).
    /// A session WITH a stored path but no resolvable file is gone for good — that
    /// gets the "unavailable" treatment instead of a spinner that never ends.
    private var isFinishingExport: Bool {
        sessionRecording.isExporting && session?.wrappedVideoPath == nil
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
        TimeFormatter.shortDuration(seconds)
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
            // The saved session path is authoritative. Avoid falling back to the
            // global live export URL here; from History that can point at a
            // different, more recent session and share/play the wrong wrap.
            return WrapStorage.resolveVideoURL(session?.wrappedVideoPath)
                ?? WrapStorage.resolveVideoURL(session?.rawClipPath)
        case .weekly, .monthly:
            return WrapStorage.resolveVideoURL(periodWrap?.videoPath)
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
        // Build the player as soon as a real video file URL exists, and rebuild if
        // the persisted path/live URL changes.
        .onAppear { syncPlayer() }
        .onChange(of: videoURL) { _, _ in syncPlayer() }
        .onChange(of: isWrapReady) { _, _ in syncPlayer() }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { note in
            guard let item = note.object as? AVPlayerItem, item === player?.currentItem else { return }
            player?.seek(to: .zero)
            player?.play()
            isPlaying = true
        }
        .sheet(item: $sharePayload) { payload in
            VideoShareSheet(payload: payload)
        }
    }

    // MARK: - Player

    /// Builds (or rebuilds) the player once a wrap file exists.
    /// No-ops while we're still waiting, or if we're already playing this exact URL.
    private func syncPlayer() {
        guard let url = videoURL else {
            player?.pause()
            player = nil
            isPlaying = false
            return
        }
        if (player?.currentItem?.asset as? AVURLAsset)?.url == url { return }
        player = AVPlayer(url: url)
        player?.actionAtItemEnd = .none
        player?.play()
        isPlaying = true
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityInputLabels(["back", "go back"])

            Spacer()

            shareButton
        }
        .padding(.horizontal, 20)
    }

    private var shareButton: some View {
        Button {
            guard let videoURL = shareableVideoURL else { return }
            shareVideo(videoURL)
        } label: {
            shareIcon
        }
        .buttonStyle(.plain)
        .disabled(shareableVideoURL == nil)
    }

    private var shareIcon: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .opacity(shareableVideoURL == nil ? 0.45 : 1)
            .accessibilityLabel("Share video")
            .accessibilityHint(
                shareableVideoURL != nil ? "Opens sharing options for this wrap video"
                    : isFinishingExport ? "Video is still finishing"
                    : "Video unavailable"
            )
            .accessibilityInputLabels(["share", "share video", "export"])
    }

    private func shareVideo(_ url: URL) {
        sharePayload = VideoSharePayload(url: url, title: displayTitle)
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
            .overlay {
                // While the titled wrap is still rendering, keep a spinner over the poster
                // frame instead of playing the not-yet-final video. When no export is
                // running and the file is gone, say so — an endless spinner here used to
                // mask permanently lost videos.
                if case .session = kind, !isWrapReady {
                    ZStack {
                        Color.black.opacity(0.4)
                        if isFinishingExport {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.3)
                                Text("Finishing your wrap…")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "video.slash.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white.opacity(0.85))
                                Text("Video unavailable")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Text("This wrap's video is no longer on this device.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Video unavailable")
                        }
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Session wrap video")
            .accessibilityValue("\(displayTitle), \(durationText), \(dateText)")
            .accessibilityHint(isPlaying ? "Video is playing" : "Video is paused")
    }

    private var playPauseButton: some View {
        Button(action: togglePlayback) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.black))
        }
        .disabled(!isWrapReady)
        .opacity(isWrapReady ? 1 : 0.5)
        .accessibilityLabel(isPlaying ? "Pause video" : "Resume video")
        .accessibilityInputLabels(isPlaying ? ["pause"] : ["resume", "play", "play video"])
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
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

// MARK: - "Not ready yet" warning (EndSession-style bottom sheet)

struct WrapNotReadyModal: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.55))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)

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
                .accessibilityLabel("Got it")
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 28)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .accessibilityAddTraits(.isModal)
        }
    }
}

struct VideoSharePayload: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

struct ImageSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let title: String
}

struct VideoShareSheet: UIViewControllerRepresentable {
    let payload: VideoSharePayload

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let item = VideoShareItemSource(payload: payload)
        let controller = UIActivityViewController(
            activityItems: [item],
            applicationActivities: [InstagramStoryActivity()]
        )
        controller.excludedActivityTypes = [.addToReadingList, .assignToContact, .markupAsPDF, .print]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ImageShareSheet: UIViewControllerRepresentable {
    let payload: ImageSharePayload

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let item = ImageShareItemSource(payload: payload)
        let controller = UIActivityViewController(
            activityItems: [item],
            applicationActivities: [InstagramStoryActivity()]
        )
        controller.excludedActivityTypes = [.addToReadingList, .assignToContact, .markupAsPDF, .print]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class VideoShareItemSource: NSObject, UIActivityItemSource {
    let payload: VideoSharePayload

    init(payload: VideoSharePayload) {
        self.payload = payload
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        payload.url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        payload.url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        payload.title
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.mpeg4Movie.identifier
    }
}

private final class ImageShareItemSource: NSObject, UIActivityItemSource {
    let payload: ImageSharePayload

    init(payload: ImageSharePayload) {
        self.payload = payload
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        payload.image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        payload.image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        payload.title
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.png.identifier
    }
}

@MainActor
private final class InstagramStoryActivity: UIActivity {
    private var item: Any?

    override class var activityCategory: UIActivity.Category {
        .share
    }

    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("com.andrianangg.lucky7.instagramStory")
    }

    override var activityTitle: String? {
        "Instagram Story"
    }

    override var activityImage: UIImage? {
        UIImage(systemName: "camera.fill")
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        guard InstagramStorySharer.canOpenStories else { return false }
        return activityItems.contains { shareableItem(from: $0) != nil }
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        item = activityItems.compactMap { shareableItem(from: $0) }.first
    }

    override func perform() {
        let didShare: Bool
        if let image = item as? UIImage {
            didShare = InstagramStorySharer.shareImage(image)
        } else if let url = item as? URL {
            didShare = InstagramStorySharer.shareVideo(url: url)
        } else {
            didShare = false
        }

        activityDidFinish(didShare)
    }

    private func shareableItem(from item: Any) -> Any? {
        if let image = item as? UIImage {
            return image.pngData() == nil ? nil : image
        }

        if let url = item as? URL {
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }

        if let source = item as? VideoShareItemSource {
            return FileManager.default.fileExists(atPath: source.payload.url.path) ? source.payload.url : nil
        }

        if let source = item as? ImageShareItemSource {
            return source.payload.image.pngData() == nil ? nil : source.payload.image
        }

        return nil
    }
}

@MainActor
enum InstagramStorySharer {
    static var canOpenStories: Bool {
        guard let storiesURL = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(storiesURL)
    }

    static func shareVideo(url: URL) -> Bool {
        guard let videoData = try? Data(contentsOf: url) else {
            return false
        }

        return openStories(with: [
            "com.instagram.sharedSticker.backgroundVideo": videoData,
            "com.instagram.sharedSticker.backgroundTopColor": "#3A8DFF",
            "com.instagram.sharedSticker.backgroundBottomColor": "#3A8DFF"
        ])
    }

    static func shareImage(_ image: UIImage) -> Bool {
        guard let imageData = image.pngData() else {
            return false
        }

        return openStories(with: [
            "com.instagram.sharedSticker.backgroundImage": imageData,
            "com.instagram.sharedSticker.backgroundTopColor": "#3A8DFF",
            "com.instagram.sharedSticker.backgroundBottomColor": "#3A8DFF"
        ])
    }

    private static func openStories(with item: [String: Any]) -> Bool {
        guard let storiesURL = URL(string: "instagram-stories://share"),
              canOpenStories else {
            return false
        }

        UIPasteboard.general.setItems(
            [item],
            options: [.expirationDate: Date().addingTimeInterval(5 * 60)]
        )
        UIApplication.shared.open(storiesURL)
        return true
    }
}

#Preview {
    WrappedVideoScreen(kind: .session(UUID()), videoFrames: [])
        .environmentObject(SessionRecordingViewModel())
        .modelContainer(for: [Session.self, PeriodWrap.self], inMemory: true)
}
