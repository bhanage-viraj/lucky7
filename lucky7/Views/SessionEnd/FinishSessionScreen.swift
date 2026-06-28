// Views/SessionEnd/FinishSessionScreen.swift

import SwiftUI
import SwiftData

private enum SessionEndStep {
    case celebration
    case details
    case analytics
}

struct FinishSessionScreen: View {
    var onFlowComplete: () -> Void

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var sessionTimer: SessionTimerViewModel
    @EnvironmentObject private var sessionRecording: SessionRecordingViewModel

    private var videoFrames: [UIImage] { sessionRecording.previewFrames }
    private let stepAnimation = Animation.spring(response: 0.44, dampingFraction: 0.9, blendDuration: 0.08)
    private var stepTransition: AnyTransition {
        .opacity
    }

    @State private var appeared = false
    @State private var step: SessionEndStep = .celebration
    @State private var sessionId: UUID?
    @State private var hasCompletedFlow = false
    @State private var previewWaitTimedOut = false

    private var canAdvanceToDetails: Bool {
        !videoFrames.isEmpty || previewWaitTimedOut
    }

    var body: some View {
        ZStack {
            switch step {
            case .celebration:
                celebrationView
                    .transition(stepTransition)
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
                                .accessibilityLabel("Saved to Photos")
                                .accessibilityAddTraits(.isStaticText)
                        }
                    }
            case .details:
                if let sessionId {
                    SessionDetails(
                        sessionId: sessionId,
                        videoFrames: videoFrames,
                        onSave: {
                            withAnimation(stepAnimation) {
                                step = .analytics
                            }
                        },
                        onFlowComplete: completeFlow
                    )
                    .transition(stepTransition)
                }
            case .analytics:
                if let sessionId {
                    SessionAnalytics(
                        sessionId: sessionId,
                        videoFrames: videoFrames,
                        onClose: completeFlow
                    )
                    .transition(stepTransition)
                }
            }
        }
        .animation(stepAnimation, value: step)
        .onAppear {
            appeared = true
            createSessionIfNeeded()
            startPreviewFallbackTimer()
            AccessibilitySupport.announce("Session complete. You stayed on track.")
        }
        .onChange(of: sessionRecording.finalVideoURL) { _, url in
            persistWrappedVideoPath(url)
        }
        .onChange(of: sessionRecording.rawClipURL) { _, url in
            persistRawClipPath(url)
        }
        .onChange(of: sessionRecording.photoAssetId) { _, id in
            persistPhotoAssetId(id)
        }
        .onChange(of: sessionRecording.previewFrames.count) { _, count in
            if count > 0 {
                RecordingDiagnostics.log("FinishSession preview ready count=\(count)")
            }
        }
    }

    private func persistPhotoAssetId(_ id: String?) {
        guard let sessionId, let id else { return }
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId })
        descriptor.fetchLimit = 1
        if let session = try? context.fetch(descriptor).first {
            session.photoAssetId = id
            try? context.save()
        }
    }

    private func persistWrappedVideoPath(_ url: URL?) {
        // Store just the filename — absolute paths die when iOS rotates the app
        // container on update; WrapStorage.resolveVideoURL finds the file at read time.
        guard let sessionId, let name = url?.lastPathComponent else { return }
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId })
        descriptor.fetchLimit = 1
        if let session = try? context.fetch(descriptor).first {
            session.wrappedVideoPath = name
            try? context.save()
            RecordingDiagnostics.log("FinishSession persist wrapped session=\(sessionId) path=\(name)")
        }
    }

    private func persistRawClipPath(_ url: URL?) {
        guard let sessionId, let name = url?.lastPathComponent else { return }
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId })
        descriptor.fetchLimit = 1
        if let session = try? context.fetch(descriptor).first {
            session.rawClipPath = name
            try? context.save()
            RecordingDiagnostics.log("FinishSession persist raw session=\(sessionId) path=\(name)")
        }
    }

    private var celebrationView: some View {
        ResponsiveReader { metrics in
            let contentWidth = min(max(metrics.width - metrics.horizontalPadding * 2, 1), metrics.isPad ? 560 : 340)
            let titleWidth = min(contentWidth, metrics.isPad ? 390 : 330)
            ZStack {
                AdaptivePatternBackground(smallPattern: true, yOffset: 0)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: metrics.isShort ? 12 : 18) {
                        Spacer(minLength: metrics.isShort ? 18 : 56)

                        ZStack {
                            Text("🤩")
                                .font(.system(size: metrics.scaled(40, min: 34, max: 48)))
                                .offset(y: metrics.isShort ? -44 : -60)
                                .rotationEffect(.degrees(-6))
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 10)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: appeared)
                                .accessibilityDecorative()

                            Image(.titleFinishSession)
                                .resizable()
                                .scaledToFit()
                                .frame(width: titleWidth)
                                .scaleEffect(appeared ? 1 : 0.7)
                                .opacity(appeared ? 1 : 0)
                                .blur(radius: appeared ? 0 : 8)
                                .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1), value: appeared)
                                .accessibilityDecorative()
                        }

                        Text("You stayed on track and got things done. Reflect on your session and see your focus stats.")
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: min(contentWidth, metrics.isPad ? 340 : 280))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.easeOut(duration: 0.6).delay(0.4), value: appeared)

                        Image(systemName: "flag.pattern.checkered.2.crossed")
                            .font(.system(size: metrics.scaled(40, min: 32, max: 46)))
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.5)
                            .animation(.spring(response: 0.7, dampingFraction: 0.5).delay(0.55), value: appeared)
                            .accessibilityDecorative()

                        Spacer(minLength: metrics.isShort ? 18 : 56)

                        Button(action: advanceToDetails) {
                            Text(canAdvanceToDetails ? "Tap to go to the next screen" : "Preparing preview...")
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .frame(minHeight: 44)
                                .opacity(appeared ? 0.8 : 0)
                                .animation(.easeIn(duration: 0.5).delay(0.8), value: appeared)
                        }
                        .disabled(!canAdvanceToDetails)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Continue to session details")
                        .accessibilityHint("Opens the screen to title and save your session")
                        .accessibilityInputLabels(["continue", "next", "session details", "tap"])
                    }
                    .foregroundStyle(.white)
                    .frame(width: contentWidth)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: metrics.height - metrics.safeArea.top - metrics.safeArea.bottom)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, metrics.safeArea.top)
                    .padding(.bottom, max(24, metrics.safeArea.bottom + 16))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: advanceToDetails)
            .accessibilityAddTraits(.isButton)
        }
    }

    private func advanceToDetails() {
        guard sessionId != nil, step == .celebration else { return }
        guard canAdvanceToDetails else {
            RecordingDiagnostics.log("FinishSession blocked details: preview not ready")
            return
        }
        showDetails(reason: videoFrames.isEmpty ? "preview timeout" : "preview ready")
    }

    private func startPreviewFallbackTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard videoFrames.isEmpty, step == .celebration else { return }
            previewWaitTimedOut = true
            RecordingDiagnostics.log("FinishSession preview wait timed out")
        }
    }

    private func showDetails(reason: String) {
        guard sessionId != nil, step == .celebration else { return }
        RecordingDiagnostics.log("FinishSession show details reason=\(reason) previewFrames=\(videoFrames.count)")
        withAnimation(stepAnimation) {
            step = .details
        }
    }

    private func createSessionIfNeeded() {
        guard sessionId == nil else { return }
        let id = sessionTimer.sessionId   // SAME id the distractions were saved under, so analytics matches
        let duration = TimeInterval(sessionTimer.configuredTotalSeconds)
        let endTime = Date()
        let session = Session(
            id: id,
            userId: UUID(),
            duration: duration,
            startTime: endTime.addingTimeInterval(-duration),
            endTime: endTime,
            wrappedVideoPath: sessionRecording.finalVideoURL?.lastPathComponent,
            rawClipPath: sessionRecording.rawClipURL?.lastPathComponent
        )
        context.insert(session)
        sessionId = id
        SessionEndRecovery.markPending(id)
        RecordingDiagnostics.log("FinishSession create session=\(id) wrapped=\(session.wrappedVideoPath ?? "nil") raw=\(session.rawClipPath ?? "nil")")
    }

    private func completeFlow() {
        guard !hasCompletedFlow else { return }
        hasCompletedFlow = true
        SessionEndRecovery.clear(sessionId)
        onFlowComplete()
    }
}

#Preview {
    FinishSessionScreen(onFlowComplete: {})
        .environmentObject(SessionTimerViewModel())
        .environmentObject(SessionRecordingViewModel())
        .modelContainer(for: Session.self, inMemory: true)
}
