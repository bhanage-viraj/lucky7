//
//  RecordingPage.swift
//  lucky7
//

import SwiftUI
import SwiftData
import AVFoundation
import UserNotifications
import Combine

// MARK: - Main View

struct RecordingPage: View {
    @State private var hasStarted = false
    @State private var groupOffset: CGFloat = 0
    @State private var showFullFocusScreen = false
    @State private var showCrashSession = false
    @State private var showNotifNudge = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionTimer: SessionTimerViewModel
    @EnvironmentObject private var sessionRecording: SessionRecordingViewModel

    #if os(iOS)
    @EnvironmentObject private var focusController: FocusViewModel
    #endif

    // jailbreak: distraction prompt + in-app unlock card + records sheet
    @State private var sessionId = UUID()
    @State private var pendingPrompt: PendingPrompt?
    @State private var unlock: UnlockInfo?
    @State private var breakBlockedInfo: BreakBlockedInfo?

    struct PendingPrompt: Identifiable {
        let id = UUID()
        let distraction: Distraction
        let tokenDataToClear: Data?
    }

    struct UnlockInfo: Identifiable {
        let id = UUID()
        let kind: BreakUnlockOverlay.Kind
        var appName: String = ""
        var tokenData: Data? = nil
        var timeText: String = ""
    }

    // shown instead of the reason form when a break is already running — only one
    // app can be unlocked at a time, so a second "Break It" is rejected with a warning.
    struct BreakBlockedInfo: Identifiable {
        let id = UUID()
        let appName: String
        let timeLeft: String
    }

    var body: some View {

        ZStack {

            CameraPreview(session: sessionRecording.captureSession)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                VStack {

                    // EXPAND BUTTON
                    Button(action: {
                        showFullFocusScreen = true
                    }) {
                        Image(systemName: "arrow.down.left.and.arrow.up.right.circle.fill")
                            .font(.system(size: 42))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.35))
                                    .frame(width: 30, height: 30)
                            )
                    }

                    // CAMERA SWITCH BUTTON
                    Button(action: {
                        sessionRecording.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                }
                .offset(x: 150, y: 0)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()
                Group {

                    VStack(spacing: 20) {

                        ZStack {

                            Image("group30")
                                .offset(x: 0, y: 80 + groupOffset)

                            Image("Rectangle39")
                                .offset(x: 0, y: 200 + groupOffset)

                            Image("Frame35")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 300, height: 250)
                                .offset(x: 0, y: 70 + groupOffset)

                            HStack(spacing: -50) {

                                TrafficShell {
                                    VStack(spacing: 2) {
                                        Text("\(sessionTimer.hours)")
                                            .font(.custom("Special Gothic Expanded One", size: 34))
                                        Text("Hours")
                                            .font(.custom("Special Gothic Expanded One", size: 10))
                                    }
                                    .foregroundStyle(.white)
                                }
                                .scaleEffect(0.70)

                                TrafficShell {
                                    VStack(spacing: 2) {
                                        Text(String(format: "%02d", sessionTimer.minutes))
                                            .font(.custom("Special Gothic Expanded One", size: 34))
                                        Text("Minutes")
                                            .font(.custom("Special Gothic Expanded One", size: 10))
                                    }
                                    .foregroundStyle(.white)
                                }
                                .scaleEffect(0.70)

                                TrafficShell {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            if !hasStarted {
                                                // FIRST START — begin recording + block distracting apps
                                                hasStarted = true
                                                sessionRecording.startRecording(
                                                    plannedSessionSeconds: TimeInterval(sessionTimer.configuredTotalSeconds)
                                                )
                                                sessionTimer.start()
                                                groupOffset = 70
                                                #if os(iOS)
                                                focusController.engage()   // jailbreak: apply the shield
                                                #endif
                                            } else if sessionTimer.isRunning {
                                                // PAUSE recording (the block stays on for the whole session)
                                                sessionTimer.pause()
                                                sessionRecording.pauseRecording()
                                                groupOffset = 0
                                            } else {
                                                // RESUME recording — and end any active break so the
                                                // unlocked app re-blocks when you go back to focusing
                                                sessionTimer.start()
                                                sessionRecording.resumeRecording()
                                                groupOffset = 70
                                                #if os(iOS)
                                                focusController.resume()
                                                #endif
                                            }
                                        }
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName:
                                                    !hasStarted
                                                  ? "play.fill"
                                                  : (sessionTimer.isRunning ? "pause.fill" : "play.fill")
                                            )
                                            .font(.system(size: 20))
                                            Text(
                                                !hasStarted
                                                ? "START"
                                                : (sessionTimer.isRunning ? "PAUSE" : "RESUME")
                                            )
                                            .font(.custom("Special Gothic Expanded One", size: 13))
                                        }
                                        .foregroundStyle(sessionTimer.isRunning ? .yellow : .white)
                                    }
                                }
                                .scaleEffect(0.70)
                            }
                            .offset(x: 0, y: 80 + groupOffset)

                            if hasStarted && !sessionTimer.isRunning {
                                Button(action: endSessionEarly) {
                                    Image("End")
                                }
                                .offset(y: 200 + groupOffset)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }
            }

            if sessionRecording.isExporting {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.4)
                    Text("Saving your video...")
                        .font(.custom("Special Gothic Expanded One", size: 16))
                        .foregroundColor(.white)
                }
            }

            if sessionRecording.permissionDenied {
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

            VStack {
                if sessionRecording.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                        Text("REC")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
                }

                Spacer()

                if let message = sessionRecording.statusMessage, !sessionRecording.isExporting {
                    Text(message)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(.bottom, 120)
                } else if sessionRecording.savedToPhotos {
                    Text("Saved to Photos ✓")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(.bottom, 120)
                }
            }
            .padding(.top, 60)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)   // recording is a full-screen mode — keep the tab bar on the home page only
        #endif
        // jailbreak: in-app "App unlocked" card that shrinks toward the island
        .overlay {
            #if os(iOS)
            if let u = unlock {
                BreakUnlockOverlay(kind: u.kind, appName: u.appName, tokenData: u.tokenData, timeText: u.timeText, onFinished: { unlock = nil })
                    .id(u.id)
            }
            #endif
        }
        .onAppear {
            sessionRecording.prepareCamera()
            checkPendingEvents()
            // The shield return relies on a tappable notification. Request it HERE (a stable
            // screen) — the splash-time request gets cancelled before the user can respond,
            // leaving the app unregistered (not even listed in Settings → Notifications). Then
            // nudge to Settings if it's been denied.
            Task {
                await NotificationPermission.requestIfNeeded()
                if await NotificationPermission.isDenied() { showNotifNudge = true }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shieldReturnTapped)) { _ in
            checkPendingEvents()   // shield-return notification received/tapped → surface the prompt
        }
        .alert("Turn on notifications", isPresented: $showNotifNudge) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Rush Hour sends a quick notification to bring you back here when you tap “Break It” or “Back to Session” on the block screen. Tap that notification to return — without notifications on, it can fail.")
        }
        .alert(
            "One break at a time",
            isPresented: Binding(get: { breakBlockedInfo != nil }, set: { if !$0 { breakBlockedInfo = nil } }),
            presenting: breakBlockedInfo
        ) { _ in
            Button("Got it", role: .cancel) { breakBlockedInfo = nil }
        } message: { info in
            Text("\(info.appName) is still unlocked — \(info.timeLeft) left. Finish that break before you can unlock another app.")
        }
        .onDisappear {
            if !sessionRecording.isExporting, !sessionRecording.isRecording {
                ScreenWakeLock.release()
            }
            if !sessionRecording.isExporting {
                sessionRecording.stopCamera()
            }
            #if os(iOS)
            // Leaving the session screen (swipe-back / pop) ends the session — stop the timer
            // AND lift the shield. The normal end flow already does both; this covers the
            // swipe-back path that otherwise left the timer ticking + every app blocked.
            if hasStarted {
                sessionTimer.pause()
                focusController.release()
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if sessionRecording.isRecording || sessionRecording.isExporting {
                    ScreenWakeLock.setActive(true)
                }
                checkPendingEvents()   // jailbreak: pick up a break taken on the shield
                cancelShieldFallbackNotifications()   // clear delivered shield notifications
                // notifications ARE the return path now — re-nudge if they got denied mid-session
                Task { if await NotificationPermission.isDenied() { showNotifNudge = true } }
            case .background:
                // left the app → pause the session instead of letting it silently freeze and
                // auto-resume; the button flips to RESUME so you pick back up deliberately
                if hasStarted && sessionTimer.isRunning {
                    sessionTimer.pause()
                    sessionRecording.pauseRecording()
                    groupOffset = 0
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: sessionTimer.showFinishSession) { _, show in
            if show {
                finalizeRecording()
                #if os(iOS)
                focusController.release()   // timer hit 00:00 — lift the shield + tear down the break Live Activity now, not after the recap
                #endif
            }
        }
        .onChange(of: sessionTimer.requestReturnToHome) { _, shouldReturn in
            guard shouldReturn else { return }
            sessionTimer.requestReturnToHome = false
            exitToHomeFromSessionFlow()
        }
        .fullScreenCover(isPresented: $showFullFocusScreen) {
            FullFocusScreen()
        }
        .fullScreenCover(isPresented: $sessionTimer.showFinishSession) {
            FinishSessionScreen(onFlowComplete: exitToHomeFromSessionFlow)
        }
        .fullScreenCover(isPresented: $showCrashSession) {
            CrashSessionScreen(onFlowComplete: exitToHomeFromSessionFlow)
        }
        // jailbreak: reason prompt when a break was taken on the shield
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
                    unlock = UnlockInfo(kind: .breakUnlock, appName: name.isEmpty ? "Blocked App" : name, tokenData: prompt.distraction.tokenData, timeText: "15:00")
                    #endif
                    try? modelContext.save()
                    pendingPrompt = nil
                }
            )
        }
    }

    // jailbreak: a break was taken on the shield → record it and prompt for a reason
    private func checkPendingEvents() {
        #if os(iOS)
        guard pendingPrompt == nil, breakBlockedInfo == nil else { return }
        guard let pair = SharedJailbreakStore.nextUnhandledBreak() else { return }

        // one break at a time: if an app is already unlocked, reject this new break —
        // keep the active break running, warn the user, and skip the reason form.
        if let active = focusController.activeBreaks.first(where: { focusController.remainingSeconds(for: $0) > 0 }) {
            let name = active.appDisplayName ?? active.appOpened
            let left = focusController.remainingSeconds(for: active)
            breakBlockedInfo = BreakBlockedInfo(
                appName: name.isEmpty ? "Blocked App" : name,
                timeLeft: String(format: "%d:%02d", Int(left) / 60, Int(left) % 60)
            )
            SharedJailbreakStore.markBreakHandled(pair.action.occurredAt)   // consume so it won't re-prompt
            return
        }

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

        // resolve the real app name now, while foregrounded on the reason screen, so it's ready
        // before the Live Activity starts (otherwise the async lookup is cut off when you leave)
        focusController.prefetchDisplayName(for: distraction)

        SharedJailbreakStore.markBreakHandled(pair.action.occurredAt)
        pendingPrompt = PendingPrompt(distraction: distraction, tokenDataToClear: tokenData)
        #endif
    }

    // .openParentalControlsApp is the primary shield→app return; the shield also queued
    // a delayed notification as a fallback. We're back in the app now, so drop it.
    private func cancelShieldFallbackNotifications() {
        // Only clear DELIVERED ones — leave any pending request to fire, since pending means the
        // app hasn't genuinely returned yet (don't kill the safety net on a transient .active).
        let ids = ["rushhour.shieldreturn", "rushhour.shieldreason"]
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    // stamp endTime on any break still open this session, so the distracted time is recorded
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
        sessionRecording.stopCamera()
        sessionRecording.resetForNewSession()
        #if os(iOS)
        closeOpenDistractions()
        focusController.release()   // jailbreak: unblock everything when the session ends
        #endif
        dismiss()
    }

    private func endSessionEarly() {
        sessionTimer.pause()
        finalizeRecording {
            showCrashSession = true
        }
    }

    private func finalizeRecording(completion: @escaping () -> Void = {}) {
        guard hasStarted else {
            completion()
            return
        }
        let wallClock = TimeInterval(sessionTimer.elapsedSeconds)
        sessionRecording.stopRecordingAndExport(wallClockSeconds: wallClock, completion: completion)
    }
}


// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
    }
}


// MARK: - Preview UIView

class PreviewView: UIView {

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        if let connection = previewLayer.connection {
            VideoOrientationHelper.applyToCaptureConnection(connection)
        }
    }
}


#Preview {
    RecordingPage()
        .environmentObject(SessionTimerViewModel())
        .environmentObject(SessionRecordingViewModel())
        .environmentObject(FocusViewModel())
        .modelContainer(for: [Session.self, Distraction.self], inMemory: true)
}
