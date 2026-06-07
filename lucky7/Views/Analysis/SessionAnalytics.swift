//
//  SessionAnalytics.swift
//  lucky7
//

import SwiftUI
import SwiftData

struct SessionAnalytics: View {
    var sessionId: UUID
    var videoFrames: [UIImage] = []
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var sessions: [Session]

    @StateObject private var distractionStat = DistractionStat()

    @State private var isShowingWrappedVideo = false
    /// Poster frame pulled from the saved wrapped video when no live capture
    /// frames are handed in (e.g. when opened from History).
    @State private var extractedThumbnail: UIImage?
    @State private var showDeleteConfirm = false
    @State private var fullscreenSnapshot: FullscreenSnapshot?

    init(sessionId: UUID, videoFrames: [UIImage] = [], onClose: (() -> Void)? = nil) {
        self.sessionId = sessionId
        self.videoFrames = videoFrames
        self.onClose = onClose
        _sessions = Query(filter: #Predicate<Session> { $0.id == sessionId })
    }

    // MARK: - Derived data

    private var session: Session? { sessions.first }

    private var savedSnapshots: [UIImage] {
        // Only the first 3 are ever shown, so decode just those — decoding all
        // stored images on every render spikes memory and crashes past ~4 photos.
        (session?.snapshotImages ?? []).prefix(3).compactMap { UIImage(data: $0) }
    }

    /// The video thumbnail always uses captured frames from the session video —
    /// the live capture frames when available, otherwise a frame extracted from
    /// the saved wrapped video. Never the user's activity snapshots.
    private var thumbnailImage: UIImage? {
        videoFrames.first ?? extractedThumbnail
    }

    private var displayTitle: String {
        let t = session?.title ?? ""
        return t.isEmpty ? "Untitled session" : t
    }

    private var displaySummary: String {
        let s = session?.summary ?? ""
        return s.isEmpty ? "No description added for this session yet." : s
    }

    // TODO: move into Utilities/TimeFormatter.swift once that file is filled
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private var wholeSessionText: String {
        formatDuration(session?.actualDuration ?? 0)
    }

    private var focusDurationText: String {
        let actual = session?.actualDuration ?? 0
        let distracted = distractionStat.totalDistractionDuration
        return formatDuration(max(actual - distracted, 0))
    }

    private var distractedDurationText: String {
        formatDuration(distractionStat.totalDistractionDuration)
    }

    private var distractionCountText: String {
        "\(distractionStat.distractionCount)x"
    }

    private var shareableVideoURL: URL? {
        guard let path = session?.wrappedVideoPath else { return nil }
        return URL(fileURLWithPath: path)
    }

    private var shareableText: String {
        """
        \(displayTitle)

        Whole session: \(wholeSessionText)
        Focus: \(focusDurationText) · Distracted: \(distractedDurationText) (\(distractionCountText))

        \(displaySummary)
        """
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

            VStack {
                HStack {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    shareButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()
            }
            .zIndex(1) // keep the top bar tappable above the ScrollView

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    statsCard
                    detailCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
                .padding(.top, 24)
            }

            VStack {
                Spacer()
                deleteButton
            }

            if showDeleteConfirm {
                deleteConfirmation
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .hidesFloatingTabBar()
        .onAppear {
            distractionStat.fetchDistractions(for: sessionId, context: context)
        }
        .task(id: sessionId) {
            await loadThumbnailIfNeeded()
        }
        .fullScreenCover(isPresented: $isShowingWrappedVideo) {
            WrappedVideoScreen(kind: .session(sessionId), videoFrames: videoFrames)
        }
        .fullScreenCover(item: $fullscreenSnapshot) { item in
            SnapshotViewer(images: savedSnapshots, startIndex: item.id)
        }
    }

    // MARK: - Subviews
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

    private var statsCard: some View {
        PatternBorderedCard(edges: [.top], cornerRadius: 30) {
            VStack(spacing: 30) {
                Spacer().frame(height: 50)

                VStack(spacing: 24) {
                    HStack {
                        StatView(title: "WHOLE SESSION", value: wholeSessionText)
                        StatView(title: "FOCUS DURATION", value: focusDurationText)
                    }
                    HStack {
                        StatView(title: "DISTRACTION COUNT", value: distractionCountText)
                        StatView(title: "DISTRACTED DURATION", value: distractedDurationText)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .overlay(alignment: .top) { playPreview.offset(y: -65) }
        .padding(.top, 70)
    }

    private var playPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let frame = thumbnailImage {
                    Image(uiImage: frame)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .foregroundColor(.gray.opacity(0.5))
                        .background(Color.white)
                }
            }
            .frame(width: 130, height: 130)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.black, lineWidth: 3))

            Button(action: { isShowingWrappedVideo = true }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
                    .padding(15)
                    .background(Circle().fill(Color.black))
            }
            .offset(x: 5, y: 5)
        }
    }

    private var detailCard: some View {
        PatternBorderedCard(edges: [.bottom], cornerRadius: 30) {
            VStack(alignment: .center, spacing: 16) {
                Text(displayTitle)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                Text(displaySummary)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(UIColor.darkGray))
                    .lineSpacing(4)
                    .padding(.horizontal, 10)

                if savedSnapshots.isEmpty {
                    Text("No activity snapshots added for this session.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .padding(.top, 10)
                } else {
                    HStack(spacing: 12) {
                        // Show up to 3 saved snapshots. Slots past the count keep
                        // a neutral placeholder so the row's rhythm stays stable
                        // when there are only 1–2 photos.
                        ForEach(0..<3, id: \.self) { index in
                            Group {
                                if index < savedSnapshots.count {
                                    Image(uiImage: savedSnapshots[index])
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Color.gray.opacity(0.2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 2))
                            .contentShape(RoundedRectangle(cornerRadius: 16))
                            .onTapGesture {
                                guard index < savedSnapshots.count else { return }
                                fullscreenSnapshot = FullscreenSnapshot(id: index)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .padding(24)
            .padding(.bottom, 16) // clearance above the bottom checkerboard strip
        }
    }

    private var deleteButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showDeleteConfirm = true }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .bold))
                Text("DELETE")
                    .font(.custom("Special Gothic Expanded One", size: 16))
            }
            .foregroundColor(Color("ButtonRed"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color("ButtonRed"), lineWidth: 2)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }

    // MARK: - Delete confirmation modal

    private var deleteConfirmation: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismissDeleteConfirm() }

            VStack(spacing: 18) {
                ZStack(alignment: .topTrailing) {
                    Text("Delete this Session")
                        .font(.custom("Special Gothic Expanded One", size: 22))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)

                    Button(action: dismissDeleteConfirm) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                }

                Text("You're about to permanently delete your session, including the timelapse and analytics.\nAre you sure?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(UIColor.darkGray))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                HStack(spacing: 14) {
                    Button {
                        showDeleteConfirm = false
                        deleteSession()
                    } label: {
                        Text("DELETE")
                            .font(.custom("Special Gothic Expanded One", size: 15))
                            .foregroundColor(Color("ButtonRed"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 30).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color("ButtonRed"), lineWidth: 2))
                    }

                    Button(action: dismissDeleteConfirm) {
                        Text("CANCEL")
                            .font(.custom("Special Gothic Expanded One", size: 15))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 30).fill(Color.black))
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black, lineWidth: 2))
            .padding(.horizontal, 12)
        }
        .zIndex(2)
        .transition(.opacity)
    }

    private func dismissDeleteConfirm() {
        withAnimation(.easeInOut(duration: 0.2)) { showDeleteConfirm = false }
    }

    // MARK: - Actions

    private func close() {
        if let onClose {
            // Live post-session flow: this tears the flow down back to Home.
            onClose()
        } else {
            // Opened from History: pop this screen and jump the root TabView to Home.
            NotificationCenter.default.post(name: .returnToHomeTab, object: nil)
            dismiss()
        }
    }

    private func deleteSession() {
        if let session = session {
            context.delete(session)
            try? context.save()
        }
        close()
    }

    /// Extracts a poster frame from the saved wrapped video when no live capture
    /// frames were passed in, so History still shows a real video frame (never a
    /// user snapshot). Decoding happens off the main thread.
    private func loadThumbnailIfNeeded() async {
        guard videoFrames.isEmpty, extractedThumbnail == nil,
              let url = shareableVideoURL else { return }

        let frame = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let image = SessionRecordingViewModel.extractPreviewFrames(from: url, count: 1).first
                continuation.resume(returning: image)
            }
        }
        extractedThumbnail = frame
    }
}

// MARK: - Reusable Stat View Component

struct StatView: View {
    var title: String
    var value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(Color(UIColor.gray))
                .kerning(1.2)
            Text(value)
                .font(.system(size: 32, weight: .black))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Fullscreen Snapshot Viewer

/// Identifies which snapshot to open in the fullscreen viewer.
struct FullscreenSnapshot: Identifiable {
    let id: Int
}

/// Fullscreen, swipeable viewer for the saved activity snapshots.
struct SnapshotViewer: View {
    let images: [UIImage]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int

    init(images: [UIImage], startIndex: Int) {
        self.images = images
        self.startIndex = startIndex
        _selection = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                }
                Spacer()
            }
            .padding(20)
        }
    }
}

#Preview {
    SessionAnalytics(sessionId: UUID(), videoFrames: [])
        .modelContainer(for: Session.self, inMemory: true)
}
