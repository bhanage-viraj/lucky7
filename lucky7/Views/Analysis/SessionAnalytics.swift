//
//  SessionAnalytics.swift
//  lucky7
//

import SwiftUI
import SwiftData

struct SessionAnalytics: View {
    var sessionId: UUID
    var videoFrames: [UIImage] = []

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var sessions: [Session]

    @StateObject private var distractionStat = DistractionStat()

    @State private var isShowingWrappedVideo = false

    init(sessionId: UUID, videoFrames: [UIImage] = []) {
        self.sessionId = sessionId
        self.videoFrames = videoFrames
        _sessions = Query(filter: #Predicate<Session> { $0.id == sessionId })
    }

    // MARK: - Derived data

    private var session: Session? { sessions.first }

    private var savedSnapshots: [UIImage] {
        (session?.snapshotImages ?? []).compactMap { UIImage(data: $0) }
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
        // TODO: lookup Timelapse by session?.videoWrapId via a service
        return nil
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
                    Button(action: { dismiss() }) {
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
                .padding(.bottom, 80)
                .padding(.top, 24)
            }

            VStack {
                Spacer()
                Button(action: deleteSession) {
                    Text("Delete Session")
                        .font(.custom("Special Gothic Expanded One", size: 16))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            distractionStat.fetchDistractions(for: sessionId, context: context)
        }
        .fullScreenCover(isPresented: $isShowingWrappedVideo) {
            WrappedVideoScreen(sessionId: sessionId, videoFrames: videoFrames)
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
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
            .padding(12)
            .background(Circle().fill(Color.white))
            .overlay(Circle().stroke(Color.black, lineWidth: 2))
    }

    private var statsCard: some View {
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
        .background(RoundedRectangle(cornerRadius: 30).fill(Color.white))
        .overlay(alignment: .top) { playPreview.offset(y: -65) }
        .padding(.top, 70)
    }

    private var playPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            // TODO: swap for the timelapse thumbnail once the timelapse pipeline is wired up
            Group {
                if let firstFrame = videoFrames.first {
                    Image(uiImage: firstFrame)
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
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.black)
                    .padding(12)
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().stroke(Color.black, lineWidth: 3))
            }
            .offset(x: 5, y: 5)
        }
    }

    private var detailCard: some View {
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
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 30).fill(Color.white))
    }

    // MARK: - Actions

    private func deleteSession() {
        if let session = session {
            context.delete(session)
            try? context.save()
        }
        dismiss()
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

#Preview {
    SessionAnalytics(sessionId: UUID(), videoFrames: [])
        .modelContainer(for: Session.self, inMemory: true)
}
