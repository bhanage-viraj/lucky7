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
    /// When true (entered from the home record button) the session begins as soon as
    /// the camera is ready, instead of waiting for the on-screen START button.
    var autoStart: Bool = false

    /// When true, RecordingPage is hosted *in place* inside HomePage rather than pushed.
    /// In that mode HomePage owns the one shared camera preview for the whole app (two
    /// `AVCaptureVideoPreviewLayer`s on a single session fight for the feed and one goes
    /// black), and morphs ITS camera into the focus circle — so this view draws no camera
    /// of its own. It ends the session via `onExit` instead of popping a navigation stack.
    var embedded: Bool = false

    /// Drives the expanded full-focus layout. A binding so an embedded host (HomePage) can
    /// morph its shared camera into the focus circle in lock-step with this view's chrome.
    @Binding var isExpanded: Bool

    var onExit: (() -> Void)? = nil

    @State private var hasStarted = false
    @State private var showEndConfirm = false
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
        var timeText: String = ""
    }

    // shown instead of the reason form when a break is already running — only one
    // app can be unlocked at a time, so a second "Break It" is rejected with a warning.
    struct BreakBlockedInfo: Identifiable {
        let id = UUID()
    }

    var body: some View {

        ZStack {

            // Expanded background — full-focus mode. Standalone only; when embedded,
            // HomePage draws the session background beneath its shared camera.
            if !embedded {
                RecordingBackground()
                    .opacity(isExpanded ? 1 : 0)
            }

            // Camera preview — STANDALONE ONLY. Morphs between full-screen fill and the
            // focus circle. When embedded, HomePage owns the single shared preview layer
            // and morphs it into the circle itself, so we draw no camera here.
            if !embedded {
                GeometryReader { geo in
                    let circleSize: CGFloat = 164
                    let cameraW: CGFloat = isExpanded ? circleSize : geo.size.width
                    let cameraH: CGFloat = isExpanded ? circleSize : geo.size.height
                    let camCenterY: CGFloat = isExpanded
                        ? geo.safeAreaInsets.top + 168
                        : geo.size.height / 2

                    ZStack {
                        // Drop-shadow behind the camera circle (expanded only)
                        Circle()
                            .fill(Color.black)
                            .frame(width: circleSize, height: circleSize)
                            .position(x: geo.size.width / 2, y: camCenterY + 10)
                            .opacity(isExpanded ? 1 : 0)

                        CameraPreview(session: sessionRecording.captureSession)
                            .frame(width: cameraW, height: cameraH)
                            .clipShape(RoundedRectangle(cornerRadius: isExpanded ? circleSize / 2 : 0))
                            .position(x: geo.size.width / 2, y: camCenterY)
                    }
                }
                .ignoresSafeArea()
            }

            VStack {
                // COUNTDOWN — live remaining time in the traffic housing, with a soft
                // rainbow glow BEHIND it (peeking out just below) while paused.
                ZStack {
                    if hasStarted && !sessionTimer.isRunning {
                        Image("RainbowEffect")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 240, height: 46)
                            .blur(radius: 14)
                            .opacity(0.85)
                            .offset(y: 28)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }

                    RecordingTrafficTimer(
                        hours: sessionTimer.hours,
                        minutes: sessionTimer.minutes,
                        seconds: sessionTimer.seconds
                    )
                }
                .padding(.top, 8)

                Spacer()

                // CONTROL BAR — stop · pause/resume · expand
                HStack {
                    // STOP — ask before ending the session early
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showEndConfirm = true } }) {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                            .overlay {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.red)
                                    .frame(width: 22, height: 22)
                            }
                    }

                    Spacer()

                    // PAUSE / RESUME
                    Button(action: togglePauseResume) {
                        Circle()
                            .fill(.white)
                            .frame(width: 82, height: 82)
                            .overlay {
                                Image(systemName: sessionTimer.isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                    }

                    Spacer()

                    // EXPAND — fullscreen focus view
                    // EXPAND — full-focus view (same camera, different chrome)
                    Button(action: { withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { isExpanded = true } }) {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .padding(.horizontal, 44)
                .padding(.bottom, 24)
            }
            .opacity(isExpanded ? 0 : 1)
            .allowsHitTesting(!isExpanded)

            // ── Expanded (full-focus) overlay ─────────────────
            expandedSessionOverlay
                .opacity(isExpanded ? 1 : 0)
                .allowsHitTesting(isExpanded)

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
                if hasStarted {
                    HStack(spacing: 7) {
                        if sessionTimer.isRunning {
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                            Text("Recording")
                        } else {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Paused")
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(sessionTimer.isRunning ? Color.red : Color(white: 0.26), in: Capsule())
                    .animation(.easeInOut(duration: 0.2), value: sessionTimer.isRunning)
                }

                Spacer()
            }
            .padding(.top, 132)   // floating recording/paused indicator below the housing
            .opacity(isExpanded ? 0 : 1)

            if showEndConfirm {
                EndSessionConfirm(
                    onEnd: {
                        showEndConfirm = false
                        endSessionEarly()
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.2)) { showEndConfirm = false }
                    }
                )
                .transition(.opacity)
                .zIndex(20)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)   // recording is a full-screen mode — keep the tab bar on the home page only
        #endif
        // jailbreak: in-app "App Unlocked" card that shrinks up into the Dynamic Island,
        // plus the "one break at a time" warning — both styled after the figma cards.
        .overlay {
            #if os(iOS)
            if let u = unlock {
                FocusAlertCard(
                    title: "App Unlocked",
                    message: "The selected app is now available for \(u.timeText)",
                    autoDismiss: true,
                    onDismiss: { unlock = nil }
                )
                .id(u.id)
            } else if let b = breakBlockedInfo {
                FocusAlertCard(
                    title: "One break at a time",
                    message: "An app is already unlocked. You can unlock another app after returning to your focus session.",
                    onDismiss: { breakBlockedInfo = nil }
                )
                .id(b.id)
            }
            #endif
        }
        .onAppear {
            if !embedded { sessionRecording.prepareCamera() }
            if autoStart { beginSession() }   // camera may already be ready (prepared on Home)
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
        .onChange(of: sessionRecording.cameraReady) { _, ready in
            if autoStart, ready { beginSession() }   // start once the camera finishes warming up
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
        .onDisappear {
            if !sessionRecording.isExporting, !sessionRecording.isRecording {
                ScreenWakeLock.release()
            }
            // Embedded: HomePage owns the shared camera and keeps it running for the home
            // preview, so don't tear it down here.
            if !embedded, !sessionRecording.isExporting {
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
                cancelAwayNudges()   // they're back — drop the "still there?" pings
                // notifications ARE the return path now — re-nudge if they got denied mid-session
                Task { if await NotificationPermission.isDenied() { showNotifNudge = true } }
            case .background:
                // left the app → pause the session instead of letting it silently freeze and
                // auto-resume; the button flips to RESUME so you pick back up deliberately
                if hasStarted && sessionTimer.isRunning {
                    sessionTimer.pause()
                    sessionRecording.pauseRecording()
                }
                #if os(iOS)
                // away from a paused session (and not on a break) → ping them to come back
                if hasStarted && focusController.activeBreaks.isEmpty {
                    scheduleAwayNudges()
                }
                #endif
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

        .fullScreenCover(isPresented: $sessionTimer.showFinishSession) {
            FinishSessionScreen(onFlowComplete: exitToHomeFromSessionFlow)
        }
        .fullScreenCover(isPresented: $showCrashSession) {
            CrashSessionScreen(onFlowComplete: exitToHomeFromSessionFlow)
        }
        // jailbreak: reason sheet over the recording when a break was taken on the shield
        .sheet(item: $pendingPrompt) { prompt in
            ReasonFormView(
                appName: prompt.distraction.appOpened.isEmpty ? "this app" : prompt.distraction.appOpened,
                onSubmit: { takeBreak($0, for: prompt) },
                onSkip: { takeBreak("", for: prompt) }
            )
            .presentationDetents([.large])
            .presentationCornerRadius(40)
            .presentationDragIndicator(.visible)
            .presentationBackground {
                LinearGradient(
                    colors: [Color(red: 0x00/255.0, green: 0x32/255.0, blue: 0x61/255.0),
                             Color(red: 0x0B/255.0, green: 0x1F/255.0, blue: 0x32/255.0)],
                    startPoint: .top, endPoint: .bottom
                )
                .overlay {
                    Image("ReasonSheetBg")
                        .resizable()
                        .scaledToFill()
                        .blendMode(.overlay)
                }
            }
            // sheet stays put until they actually submit or cancel — no swipe-away
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Expanded (full-focus) overlay

    @ViewBuilder
    private var expandedSessionOverlay: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 24)

            // Paused badge (top-left)
            HStack {
                Text("PAUSED")
                    .foregroundStyle(.white)
                    .font(.system(size: 14))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.canvasRed))
                    )
                    .opacity(sessionTimer.isRunning ? 0 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)

            Color.clear.frame(height: 40)

            // Space for the camera circle (rendered in the camera layer)
            Color.clear.frame(height: 164)

            // Traffic-light timer
            ZStack(alignment: .center) {
                if !sessionTimer.isRunning {
                    Image(.redYellowGreen)
                        .frame(height: 136)
                }

                Image(.trafficLight)

                HStack {
                    Text("\(sessionTimer.hours)")
                        .font(.custom("Special Gothic Expanded One", size: 34))
                        .frame(width: 104, height: 102)

                    Text(String(format: "%02d", sessionTimer.minutes))
                        .font(.custom("Special Gothic Expanded One", size: 34))
                        .frame(width: 104, height: 102)

                    Text(String(format: "%02d", sessionTimer.seconds))
                        .font(.custom("Special Gothic Expanded One", size: 34))
                        .frame(width: 110, height: 102)
                        .clipped()
                }
                .foregroundStyle(.white)
                .frame(height: 136)
                .zIndex(2.0)
                .offset(y: -8)
            }
            .padding(.top, 36)

            Spacer()

            VStack(alignment: .center) {
                Text("Tips:")
                Text("Don't forget to take break")
            }
            .opacity(0.5)
            .foregroundStyle(.white)

            Spacer()

            // Bottom control bar — same actions as minimized, different style
            HStack {
                // STOP
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { showEndConfirm = true }
                }) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.75))
                            .frame(width: 56, height: 56)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.red)
                            .frame(width: 20, height: 20)
                    }
                }

                Spacer()

                // PAUSE / RESUME (uses the unified togglePauseResume)
                Button(action: togglePauseResume) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.75))
                            .frame(width: 100, height: 100)
                        Image(systemName: sessionTimer.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.black)
                    }
                }

                Spacer()

                // MINIMIZE — shrink back to the recording page layout
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        isExpanded = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.75))
                            .frame(width: 56, height: 56)
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 18))
                            .foregroundStyle(.black)
                    }
                }
            }
            .padding(.horizontal, 24)

            Color.clear.frame(height: 16)
        }
    }

    private func takeBreak(_ reason: String, for prompt: PendingPrompt) {
        prompt.distraction.reason = reason
        prompt.distraction.reasonSubmitted = true
        #if os(iOS)
        focusController.grantBreak(for: prompt.distraction)
        let secs = Int(FocusViewModel.breakDuration)
        unlock = UnlockInfo(timeText: String(format: "%d:%02d", secs / 60, secs % 60))
        #endif
        try? modelContext.save()
        pendingPrompt = nil
    }

    // nudge the user back when they leave a paused session sitting for a while (10 + 20 min)
    private func scheduleAwayNudges() {
        let ids = ["rushhour.awaynudge.1", "rushhour.awaynudge.2"]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        for (i, minutes) in [10, 20].enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Are you still there?"
            content.body = "Your focus session is paused — tap to jump back in."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
            center.add(UNNotificationRequest(identifier: ids[i], content: content, trigger: trigger))
        }
    }

    private func cancelAwayNudges() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["rushhour.awaynudge.1", "rushhour.awaynudge.2"])
    }

    // jailbreak: a break was taken on the shield → record it and prompt for a reason
    private func checkPendingEvents() {
        #if os(iOS)
        guard pendingPrompt == nil, breakBlockedInfo == nil, unlock == nil else { return }
        guard let pair = SharedJailbreakStore.nextUnhandledBreak() else { return }

        // one break at a time: if an app is already unlocked, reject this new break —
        // keep the active break running, warn the user, and skip the reason form.
        if focusController.activeBreaks.contains(where: { focusController.remainingSeconds(for: $0) > 0 }) {
            breakBlockedInfo = BreakBlockedInfo()
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
            sessionId: sessionTimer.sessionId,
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
        let sid = sessionTimer.sessionId
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
            isExpanded = false
            sessionTimer.showFinishSession = false
        }
        sessionTimer.pause()
        // Embedded: keep the shared camera running so it flows straight back into the
        // home preview as the frame shrinks; standalone: tear it down.
        if !embedded { sessionRecording.stopCamera() }
        sessionRecording.resetForNewSession()
        #if os(iOS)
        closeOpenDistractions()
        focusController.release()   // jailbreak: unblock everything when the session ends
        #endif
        if let onExit { onExit() } else { dismiss() }
    }

    // Begins the focus session: starts the timelapse capture, the countdown, and
    // (on iOS) the app shield. Used by both the on-screen START button and the
    // auto-start path when arriving from the home record button.
    private func beginSession() {
        guard !hasStarted, sessionRecording.cameraReady else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            hasStarted = true
            sessionRecording.startRecording(
                plannedSessionSeconds: TimeInterval(sessionTimer.configuredTotalSeconds)
            )
            sessionTimer.start()
            #if os(iOS)
            focusController.engage()   // jailbreak: apply the shield
            #endif
        }
    }

    // Center control: pause a running session or resume a paused one.
    private func togglePauseResume() {
        guard hasStarted else { beginSession(); return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if sessionTimer.isRunning {
                // PAUSE recording (the block stays on for the whole session)
                sessionTimer.pause()
                sessionRecording.pauseRecording()
            } else {
                // RESUME recording — and end any active break so the unlocked
                // app re-blocks when you go back to focusing
                sessionTimer.start()
                sessionRecording.resumeRecording()
                #if os(iOS)
                focusController.resume()
                #endif
            }
        }
    }

    private func endSessionEarly() {
        sessionTimer.pause()
        #if os(iOS)
        focusController.release()   // lift the shield the moment they end, not after the recap
        #endif
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


// MARK: - Countdown housing
//
// Compact, label-less version of the home traffic housing: three Trafficshell1
// grille panels in a dark rounded bar, showing the live remaining time.

private struct RecordingTrafficTimer: View {
    let hours: Int
    let minutes: Int
    let seconds: Int

    private let panelSize: CGFloat = 74

    var body: some View {
        HStack(spacing: 8) {
            panel(text: "\(hours)")
            panel(text: String(format: "%02d", minutes))
            panel(text: String(format: "%02d", seconds))
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        )
    }

    private func panel(text: String) -> some View {
        let h = panelSize * 129.0 / 117.0   // native Trafficshell1 ratio
        return ZStack {
            Image("Trafficshell1")
                .resizable()
                .frame(width: panelSize, height: h)
            Text(text)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(.white)
                .offset(y: -h * 0.12)   // nudge onto the grille center
        }
    }
}

// MARK: - End Session confirmation

struct EndSessionConfirm: View {
    let onEnd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 38, height: 5)
                    .padding(.top, 10)

                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)

                Text("End Session")
                    .font(.custom("Special Gothic Expanded One", size: 22))
                    .foregroundStyle(.black)
                    .padding(.top, 2)

                Text("Ending now will stop recording\nand end your session early")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                HStack(spacing: 14) {
                    Button(action: onEnd) {
                        Text("END")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(Capsule().stroke(Color.red, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)

                    Button(action: onCancel) {
                        Text("CANCEL")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
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
    RecordingPage(isExpanded: .constant(false))
        .environmentObject(SessionTimerViewModel())
        .environmentObject(SessionRecordingViewModel())
        .environmentObject(FocusViewModel())
        .modelContainer(for: [Session.self, Distraction.self], inMemory: true)
}
