// Views/SessionEnd/CrashSessionScreen.swift

import SwiftUI
import SwiftData

private enum SessionEndStep {
    case celebration
    case details
    case analytics
}

struct CrashSessionScreen: View {
    var onFlowComplete: () -> Void

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var sessionTimer: SessionTimerViewModel
    @EnvironmentObject private var sessionRecording: SessionRecordingViewModel

    private var videoFrames: [UIImage] { sessionRecording.previewFrames }

    @State private var appeared = false
    @State private var shake = false
    @State private var step: SessionEndStep = .celebration
    @State private var sessionId: UUID?
    @State private var hasCompletedFlow = false

    var body: some View {
        Group {
            switch step {
            case .celebration:
                celebrationView
                    .overlay { exportOverlay }
                    .overlay(alignment: .bottom) {
                        if sessionRecording.savedToPhotos {
                            Text("Saved to Photos")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.8))
                                .clipShape(Capsule())
                                .padding(.bottom, 48)
                        }
                    }
            case .details:
                if let sessionId {
                    SessionDetails(
                        sessionId: sessionId,
                        videoFrames: videoFrames,
                        onSave: { step = .analytics },
                        onFlowComplete: completeFlow
                    )
                }
            case .analytics:
                if let sessionId {
                    SessionAnalytics(
                        sessionId: sessionId,
                        videoFrames: videoFrames,
                        onClose: completeFlow
                    )
                }
            }
        }
        .onAppear {
            appeared = true
            shake = true
            createSessionIfNeeded()
            AccessibilitySupport.announce("Session ended early")
        }
        .onChange(of: sessionRecording.finalVideoURL) { _, url in
            persistWrappedVideoPath(url)
        }
        .onChange(of: sessionRecording.rawClipURL) { _, url in
            persistRawClipPath(url)
        }
    }

    private func persistWrappedVideoPath(_ url: URL?) {
        guard let sessionId, let path = url?.path else { return }
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId })
        descriptor.fetchLimit = 1
        if let session = try? context.fetch(descriptor).first {
            session.wrappedVideoPath = path
            try? context.save()
        }
    }

    private func persistRawClipPath(_ url: URL?) {
        guard let sessionId, let path = url?.path else { return }
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId })
        descriptor.fetchLimit = 1
        if let session = try? context.fetch(descriptor).first {
            session.rawClipPath = path
            try? context.save()
        }
    }

    private var celebrationView: some View {
        ZStack {
            LinearGradient(
                    colors: [Color(hex: "003261"), Color(hex: "0B1F32")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

            Image("PatternBackgroundSmall")
                .ignoresSafeArea()
                .accessibilityDecorative()

            VStack {
                Spacer()

                ZStack {
                    Text("🤕")
                        .font(.system(size: 112))
                        .offset(x: 68, y: -32)
                        .rotationEffect(.degrees(appeared ? 9 : 30))
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 1.4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.4).delay(0.2), value: appeared)
                        .accessibilityDecorative()

                    Image(.titleEndSession)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -20)
                        .blur(radius: appeared ? 0 : 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.05), value: appeared)
                        .accessibilityDecorative()
                }
                .offset(x: shake ? -8 : 0)
                .animation(
                    .interpolatingSpring(stiffness: 600, damping: 8)
                    .repeatCount(4, autoreverses: true)
                    .delay(0.1),
                    value: shake
                )

                Text("Oh no, looks like you got distracted this session. Take a moment, reset, and try again.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .frame(width: 240)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: appeared)

                Color.clear
                    .frame(height: 2)

                Image(systemName: "car.side.rear.and.collision.and.car.side.front")
                    .font(.system(size: 40))
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.4).delay(0.6), value: appeared)
                    .accessibilityDecorative()

                Spacer()

                Button {
                    guard sessionId != nil else { return }
                    step = .details
                } label: {
                    Text("Tap to go to the next screen")
                        .font(.system(size: 14))
                        .opacity(appeared ? 0.8 : 0)
                        .animation(.easeIn(duration: 0.5).delay(0.9), value: appeared)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue to session details")
                .accessibilityHint("Opens the screen to title and save your session")
                .accessibilityInputLabels(["continue", "next", "session details"])
            }
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var exportOverlay: some View {
        if sessionRecording.isExporting {
            Color.black.opacity(0.55).ignoresSafeArea().accessibilityDecorative()
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Generating your Wrap...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Generating your session wrap video")
        }
    }

    private func createSessionIfNeeded() {
        guard sessionId == nil else { return }
        let id = sessionTimer.sessionId   // SAME id the distractions were saved under, so analytics matches
        let duration = TimeInterval(sessionTimer.elapsedSeconds)
        let endTime = Date()
        let session = Session(
            id: id,
            userId: UUID(),
            duration: TimeInterval(sessionTimer.configuredTotalSeconds),
            startTime: endTime.addingTimeInterval(-duration),
            endTime: endTime,
            wrappedVideoPath: sessionRecording.finalVideoURL?.path,
            rawClipPath: sessionRecording.rawClipURL?.path
        )
        context.insert(session)
        sessionId = id
    }

    private func completeFlow() {
        guard !hasCompletedFlow else { return }
        hasCompletedFlow = true
        onFlowComplete()
    }
}

#Preview {
    CrashSessionScreen(onFlowComplete: {})
        .environmentObject(SessionTimerViewModel())
        .environmentObject(SessionRecordingViewModel())
        .modelContainer(for: Session.self, inMemory: true)
}

// MARK: - Extension Color

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
