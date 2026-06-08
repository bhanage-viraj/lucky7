//
//  RecordingPage.swift
//  lucky7
//

import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Main View

struct RecordingPage: View {
    @State private var showFullFocusScreen = false
    @State private var showCrashSession = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionTimer: SessionTimerViewModel
    @EnvironmentObject private var sessionRecording: SessionRecordingViewModel
    @EnvironmentObject private var recordingSession: RecordingSessionState

    #if os(iOS)
    @EnvironmentObject private var focusController: FocusViewModel
    #endif

    @State private var sessionId = UUID()
    @State private var pendingPrompt: PendingPrompt?
    @State private var unlock: UnlockInfo?

    struct PendingPrompt: Identifiable {
        let id = UUID()
        let distraction: Distraction
        let tokenDataToClear: Data?
    }

    struct UnlockInfo: Identifiable {
        let id = UUID()
        let appName: String
    }

    private var isPaused: Bool {
        recordingSession.isActive && !sessionTimer.isRunning
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: sessionRecording.captureSession)
                .id(sessionRecording.previewRefreshID)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TrafficFrameCountdownOverlay(
                    hours: sessionTimer.hours,
                    minutes: sessionTimer.minutes,
                    seconds: sessionTimer.seconds
                )
                .equatable()
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .allowsHitTesting(false)

                if isPaused {
                    PausedBadge()
                        .padding(.top, 10)
                }

                Spacer()

                RecordingControlsBar(
                    showStopButton: isPaused,
                    isRunning: sessionTimer.isRunning,
                    onStop: { recordingSession.requestEndConfirmation() },
                    onPlayPause: togglePlayPause,
                    onMinimize: { showFullFocusScreen = true }
                )
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 20)

            if sessionRecording.isExporting {
                exportOverlay
            }

            if sessionRecording.permissionDenied {
                permissionOverlay
            }

            if showCrashSession {
                CrashSessionScreen(onFlowComplete: exitToHomeFromSessionFlow)
                    .transition(.opacity)
            }
        }
        .overlay {
            #if os(iOS)
            if let u = unlock {
                BreakUnlockOverlay(appName: u.appName, onFinished: { unlock = nil })
                    .id(u.id)
            }
            #endif
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: handleAppear)
        .onChange(of: sessionRecording.cameraReady) { _, ready in
            if ready, recordingSession.isActive, !recordingSession.hasStartedCapture {
                let didStart = recordingSession.startCapture(
                    timer: sessionTimer,
                    recording: sessionRecording
                )
                if didStart {
                    Task {
                        try? await Task.sleep(for: .milliseconds(200))
                        #if os(iOS)
                        focusController.engage()
                        #endif
                    }
                }
            }
        }
        .onChange(of: sessionTimer.showFinishSession) { _, show in
            if show { finalizeRecording() }
        }
        .onChange(of: sessionTimer.requestReturnToHome) { _, shouldReturn in
            guard shouldReturn else { return }
            sessionTimer.requestReturnToHome = false
            exitToHomeFromSessionFlow()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if sessionRecording.isRecording || sessionRecording.isExporting {
                    ScreenWakeLock.setActive(true)
                }
                checkPendingEvents()
            }
        }
        .sheet(isPresented: $recordingSession.showEndConfirmation) {
            EndSessionSheet(
                onConfirm: confirmEndSession,
                onCancel: { recordingSession.dismissEndConfirmation() }
            )
            .presentationDetents([.height(248)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .fullScreenCover(isPresented: $showFullFocusScreen) {
            FullFocusScreen()
        }
        .fullScreenCover(isPresented: $sessionTimer.showFinishSession) {
            FinishSessionScreen(onFlowComplete: exitToHomeFromSessionFlow)
        }
        .fullScreenCover(item: $pendingPrompt) { prompt in
            DistractionPromptScreen(
                appName: prompt.distraction.appOpened.isEmpty ? "this app" : prompt.distraction.appOpened,
                countToday: 1,
                startAtReason: true,
                onBackToSession: {
                    modelContext.delete(prompt.distraction)
                    try? modelContext.save()
                    pendingPrompt = nil
                },
                onBreakWithReason: { reason in
                    prompt.distraction.reason = reason
                    prompt.distraction.reasonSubmitted = true
                    #if os(iOS)
                    focusController.grantBreak(for: prompt.distraction)
                    let name = prompt.distraction.appDisplayName ?? prompt.distraction.appOpened
                    unlock = UnlockInfo(appName: name.isEmpty ? "That app" : name)
                    #endif
                    try? modelContext.save()
                    pendingPrompt = nil
                }
            )
        }
    }

    private var exportOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
                Text("Saving your video...")
                    .font(.custom("Special Gothic Expanded One", size: 16))
                    .foregroundColor(.white)
            }
        }
        .allowsHitTesting(false)
    }

    private var permissionOverlay: some View {
        VStack(spacing: 12) {
            Text("Camera access is required to record your timelapse.")
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
    }

    private func handleAppear() {
        let didStart = recordingSession.startCapture(
            timer: sessionTimer,
            recording: sessionRecording
        )

        if didStart {
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                #if os(iOS)
                focusController.engage()
                #endif
            }
        }

        checkPendingEvents()
    }

    private func checkPendingEvents() {
        #if os(iOS)
        guard pendingPrompt == nil else { return }
        guard let pair = SharedJailbreakStore.nextUnhandledBreak() else { return }

        let tokenData = pair.action.tokenData ?? pair.config?.tokenData
        let displayName = pair.config?.displayName
            ?? pair.action.displayName
            ?? SharedJailbreakStore.lastShieldedAppName()
            ?? ""
        let bundleId = pair.config?.bundleId
            ?? pair.action.bundleId
            ?? SharedJailbreakStore.lastShieldedBundleId()

        let distraction = Distraction(
            sessionId: sessionId,
            appOpened: displayName,
            startTime: pair.config?.occurredAt ?? pair.action.occurredAt,
            tokenData: tokenData,
            appBundleId: bundleId,
            appDisplayName: displayName.isEmpty ? nil : displayName,
            sourceKind: "shieldAction",
            actionTaken: "break"
        )
        modelContext.insert(distraction)
        try? modelContext.save()

        SharedJailbreakStore.markBreakHandled(pair.action.occurredAt)
        pendingPrompt = PendingPrompt(distraction: distraction, tokenDataToClear: tokenData)
        #endif
    }

    private func closeOpenDistractions() {
        let sid = sessionId
        let descriptor = FetchDescriptor<Distraction>(
            predicate: #Predicate { $0.sessionId == sid }
        )
        if let all = try? modelContext.fetch(descriptor) {
            for d in all where d.endTime == nil { d.endTime = .now }
            try? modelContext.save()
        }
    }

    private func exitToHomeFromSessionFlow() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showCrashSession = false
            showFullFocusScreen = false
            sessionTimer.showFinishSession = false
        }
        sessionTimer.pause()
        $sessionTimer.prepareForSession
        sessionRecording.resetForNewSession()
        recordingSession.markEnded()
        #if os(iOS)
        closeOpenDistractions()
        focusController.release()
        #endif
    }

    private func togglePlayPause() {
        if sessionTimer.isRunning {
            sessionTimer.pause()
            sessionRecording.pauseRecording()
        } else if recordingSession.isActive {
            sessionTimer.start()
            sessionRecording.resumeRecording()
        }
    }

    private func confirmEndSession() {
        recordingSession.dismissEndConfirmation()
        endSessionEarly()
    }

    private func endSessionEarly() {
        sessionTimer.pause()
        sessionRecording.pauseRecording()
        showCrashSession = true
        let wallClock = TimeInterval(sessionTimer.elapsedSeconds)
        sessionRecording.stopRecordingAndExport(wallClockSeconds: wallClock) { }
    }

    private func finalizeRecording(completion: @escaping () -> Void = {}) {
        guard recordingSession.isActive else {
            completion()
            return
        }
        let wallClock = TimeInterval(sessionTimer.elapsedSeconds)
        sessionRecording.stopRecordingAndExport(wallClockSeconds: wallClock, completion: completion)
    }
}

// MARK: - Recording UI Components

private struct EndSessionSheet: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private let endRed = Color.red
    private let gothicFont = "Special Gothic Expanded One"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(white: 0.45))
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)

            VStack(spacing: 10) {
                Text("End Session")
                    .font(.custom(gothicFont, size: 24))
                    .foregroundStyle(.black)

                Text("Ending now will stop recording and end your session early")
                    .font(.custom(gothicFont, size: 17))
                    .foregroundStyle(Color(white: 0.28))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 2)

            HStack(spacing: 12) {
                Button(action: onConfirm) {
                    Text("END")
                        .font(.custom(gothicFont, size: 14))
                        .foregroundStyle(endRed)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(endRed, lineWidth: 1.5)
                        }
                }

                Button(action: onCancel) {
                    Text("CANCEL")
                        .font(.custom(gothicFont, size: 14))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.black, in: Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 16)
        }
        .background(Color.white)
    }
}

private struct PausedBadge: View {
    var body: some View {
        Text("PAUSED")
            .font(.system(size: 11, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.red, in: Capsule())
    }
}

private struct RecordingControlsBar: View {
    let showStopButton: Bool
    let isRunning: Bool
    let onStop: () -> Void
    let onPlayPause: () -> Void
    let onMinimize: () -> Void

    var body: some View {
        HStack(spacing: 36) {
            Button(action: onStop) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 52, height: 52)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red)
                        .frame(width: 18, height: 18)
                }
                .contentShape(Circle())
            }
            .opacity(showStopButton ? 1 : 0)
            .allowsHitTesting(showStopButton)
            .frame(width: 52, height: 52)
            .buttonStyle(.plain)

            Button(action: onPlayPause) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 74, height: 74)

                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.black)
                }
                .contentShape(Circle())
            }
            .frame(width: 74, height: 74)
            .buttonStyle(.plain)

            Button(action: onMinimize) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 52, height: 52)

                    Image(systemName: "arrow.down.left.and.arrow.up.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .contentShape(Circle())
            }
            .frame(width: 52, height: 52)
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.isUserInteractionEnabled = false
        view.attachSession(session)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.isUserInteractionEnabled = false
        uiView.attachSession(session)
    }
}

class PreviewView: UIView {
    private var lastAppliedBounds: CGRect = .zero

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func attachSession(_ session: AVCaptureSession) {
        previewLayer.videoGravity = .resizeAspectFill

        if previewLayer.session !== session {
            previewLayer.session = session
        } else if window != nil {
            previewLayer.session = nil
            previewLayer.session = session
        }

        refreshOrientationIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        refreshOrientationIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds

        guard bounds != lastAppliedBounds else { return }
        lastAppliedBounds = bounds
        refreshOrientationIfNeeded()
    }

    private func refreshOrientationIfNeeded() {
        guard previewLayer.session?.isRunning == true,
              let connection = previewLayer.connection else { return }
        VideoOrientationHelper.applyToCaptureConnection(connection)
    }
}

#Preview {
    NavigationStack {
        RecordingPage()
    }
    .environmentObject(SessionTimerViewModel())
    .environmentObject(SessionRecordingViewModel())
    .environmentObject(RecordingSessionState())
    .environmentObject(FocusViewModel())
    .modelContainer(for: [Session.self, Distraction.self], inMemory: true)
}
