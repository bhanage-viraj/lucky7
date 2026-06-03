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
        }
        .onChange(of: sessionRecording.finalVideoURL) { _, url in
            persistWrappedVideoPath(url)
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

    private var celebrationView: some View {
        ZStack {
            Color("CanvasRed")
                .ignoresSafeArea()

            Image("PatternBackgroundSmall")
                .ignoresSafeArea()

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

                    Image(.titleEndSession)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -20)
                        .blur(radius: appeared ? 0 : 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.05), value: appeared)
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

                Spacer()

                Text("Tap to go to the next screen")
                    .font(.system(size: 14))
                    .opacity(appeared ? 0.8 : 0)
                    .animation(.easeIn(duration: 0.5).delay(0.9), value: appeared)
            }
            .foregroundStyle(.white)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard sessionId != nil else { return }
            step = .details
        }
    }

    @ViewBuilder
    private var exportOverlay: some View {
        if sessionRecording.isExporting {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Generating your Wrap...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    private func createSessionIfNeeded() {
        guard sessionId == nil else { return }
        let id = UUID()
        let duration = TimeInterval(sessionTimer.elapsedSeconds)
        let endTime = Date()
        let session = Session(
            id: id,
            userId: UUID(),
            duration: TimeInterval(sessionTimer.configuredTotalSeconds),
            startTime: endTime.addingTimeInterval(-duration),
            endTime: endTime,
            wrappedVideoPath: sessionRecording.finalVideoURL?.path
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
