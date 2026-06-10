import SwiftUI
import AVFoundation

// MARK: - Home Page
//
// New home screen: a live camera "card" with the traffic-light duration picker.
// The record button is gray until a duration is set, then turns red — tapping it
// does NOT push a new screen. Instead the *same* camera frame enlarges to fill the
// screen and the home controls cross-fade into the recording controls in place.

struct HomePage: View {

    /// Whether the Home tab is the one currently on screen. The tab bar keeps both
    /// tabs alive (opacity-swapped), so `onAppear`/`onDisappear` alone can't tell when
    /// Home is hidden — this drives the camera lifecycle so the live preview only runs
    /// while Home is actually visible.
    var isActiveTab: Bool = true

    @EnvironmentObject private var sessionTimer: SessionTimerViewModel
    @EnvironmentObject private var sessionRecording: SessionRecordingViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var hours = 0
    @State private var minutes = 0
    @State private var seconds = 0

    // One-time home coachmarks — hidden permanently after the first interaction.
    @AppStorage("homeTipDurationSeen") private var tipDurationSeen = false
    @AppStorage("homeTipStartSeen") private var tipStartSeen = false

    @State private var showSettings = false

    /// false = home card; true = full-screen session. Drives the enlarge transition.
    @State private var sessionActive = false

    /// true once the session is pushed into full-focus mode — morphs the one shared camera
    /// from the session card down into the focus circle. Shared with the embedded RecordingPage.
    @State private var isFocusExpanded = false
    // Safe-area insets, read once, so the camera card lines up under the header / above
    // the tab bar while the camera itself ignores the safe area (to animate to full screen).
    @State private var safeTop: CGFloat = 47
    @State private var safeBottom: CGFloat = 34

    private let transition = Animation.spring(response: 0.5, dampingFraction: 0.86)

    private var isReadyToRecord: Bool {
        hours > 0 || minutes > 0 || seconds > 0
    }

    private var showSetupTip: Bool { !isReadyToRecord && !tipDurationSeen }
    private var showStartTip: Bool { isReadyToRecord && !tipStartSeen }

    var body: some View {
        ZStack {
            // 1a. Home background — fades out during a session.
            BackgroundPatternView()
                .opacity(sessionActive ? 0 : 1)

            // 1b. Session background (matches FullFocusScreen) — fades in around the frame.
            RecordingBackground()
                .opacity(sessionActive ? 1 : 0)

            // 2. The single, persistent camera — ONE preview layer for the whole app so it
            //    never fights another layer for the feed. Its frame animates across three
            //    states: home card → full session card → focus circle.
            GeometryReader { geo in
                let circleSize: CGFloat = 164
                let isCircle = sessionActive && isFocusExpanded

                // Card insets (home vs in-session), measured from the screen edges. Active
                // frame: top sits 6pt below the countdown housing; bottom 6pt below pause.
                let topInset = sessionActive ? safeTop + 60 : safeTop + 120
                let bottomInset = sessionActive ? safeBottom + 28 : safeBottom + 122
                let hInset: CGFloat = sessionActive ? 12 : 16

                let cardW = max(geo.size.width - hInset * 2, 0)
                let cardH = max(geo.size.height - topInset - bottomInset, 0)

                let camW = isCircle ? circleSize : cardW
                let camH = isCircle ? circleSize : cardH
                let centerY = isCircle ? safeTop + 168 : topInset + cardH / 2
                let corner: CGFloat = isCircle ? circleSize / 2 : (sessionActive ? 30 : 34)

                CameraPreview(session: sessionRecording.captureSession)
                    .frame(width: camW, height: camH)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .overlay {
                        if !isCircle {
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.5), lineWidth: 3)
                                .accessibilityDecorative()
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Camera preview")
                    .accessibilityHint("Live view from your device camera")
                    .accessibilityValue(
                        sessionActive
                            ? AccessibilitySupport.cameraPreviewValue(
                                isRecording: sessionRecording.isRecording,
                                isPaused: sessionActive && !sessionTimer.isRunning,
                                frameCount: sessionRecording.capturedFrameCount,
                                remainingHours: sessionTimer.hours,
                                remainingMinutes: sessionTimer.minutes,
                                remainingSeconds: sessionTimer.seconds
                              )
                            : "Ready to start a focus session"
                    )
                    .accessibilityAddTraits(sessionActive ? .updatesFrequently : [])
                    .position(x: geo.size.width / 2, y: centerY)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isFocusExpanded)
                    .animation(transition, value: sessionActive)
            }
            .ignoresSafeArea()

            // 3. Home controls (header + duration picker + record + flip) — fade out.
            HomeControls(
                hours: $hours,
                minutes: $minutes,
                seconds: $seconds,
                isReadyToRecord: isReadyToRecord,
                cameraReady: sessionRecording.cameraReady,
                showSetupTip: showSetupTip,
                showStartTip: showStartTip,
                onSettings: { showSettings = true },
                onFlip: { sessionRecording.switchCamera() },
                onRecord: startSession
            )
            .opacity(sessionActive ? 0 : 1)
            .allowsHitTesting(!sessionActive)

            // 4. Recording controls, hosted in place over the now-full-screen camera.
            if sessionActive {
                RecordingPage(
                    autoStart: true,
                    embedded: true,
                    isExpanded: $isFocusExpanded,
                    onExit: {
                        isFocusExpanded = false   // reset focus state when the session ends
                        endSession()
                    }
                )
                .hidesFloatingTabBar()
                .transition(.opacity)
            }
        }
        .background(safeAreaReader)
        .onAppear {
            if isActiveTab { sessionRecording.prepareCamera() }
        }
        .onDisappear { stopPreviewIfIdle() }
        .onChange(of: isActiveTab) { _, active in
            if active { sessionRecording.prepareCamera() }
            else { stopPreviewIfIdle() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if isActiveTab { sessionRecording.prepareCamera() }
            case .background, .inactive:
                stopPreviewIfIdle()
            @unknown default:
                break
            }
        }
        .onChange(of: sessionActive) { _, active in
            if !active { sessionRecording.prepareCamera() }   // session ended → resume home preview
            AccessibilitySupport.announce(active ? "Focus session started" : "Returned to home")
        }
        .onChange(of: isReadyToRecord) { _, ready in
            if ready { tipDurationSeen = true }   // first duration set → drop the setup tip for good
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsScreen()
        }
    }

    private var safeAreaReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    safeTop = proxy.safeAreaInsets.top
                    safeBottom = proxy.safeAreaInsets.bottom
                }
        }
        .ignoresSafeArea()
    }

    private func startSession() {
        guard isReadyToRecord, sessionRecording.cameraReady else { return }
        tipStartSeen = true   // first session start → drop the "start" tip for good
        sessionTimer.configure(hours: hours, minutes: minutes, seconds: seconds)
        withAnimation(transition) { sessionActive = true }
    }

    private func endSession() {
        withAnimation(transition) { sessionActive = false }
    }

    private func stopPreviewIfIdle() {
        guard !sessionActive,
              !sessionRecording.isRecording,
              !sessionRecording.isExporting else { return }
        sessionRecording.stopCamera()
    }
}

// MARK: - Background

struct BackgroundPatternView: View {
    var body: some View {
        // Color is the (flexible) base so the pattern image can't drive layout width.
        // group45 is a 964×964 asset — left non-resizable it would inflate the whole
        // screen's width and blow up everything sized off it.
        Color.blue
            .overlay {
                Image("group45")
                    .resizable()
                    .scaledToFill()
                    .allowsHitTesting(false)
            }
            .clipped()
            .ignoresSafeArea()
            .accessibilityDecorative()
    }
}

// MARK: - Session background (matches FullFocusScreen)

struct RecordingBackground: View {
    var body: some View {
        ZStack {
            Color("CanvasDarkGrey")
                .ignoresSafeArea()

            Image("PatternBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .offset(x: -20, y: 2)

            VStack {
                Spacer()
                Image("bottomBlur")
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .accessibilityDecorative()
    }
}

// MARK: - Header

private struct HomeHeader: View {
    let onSettings: () -> Void

    var body: some View {
        ZStack {
            Image("Hrushhour")
                .resizable()
                .scaledToFit()
                .frame(height: 36)
                .accessibilityDecorative()

            HStack {
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Settings")
                .accessibilityHint("Opens app settings")
                .accessibilityInputLabels(["settings", "open settings", "gear"])
                Spacer()
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 44)
    }
}

// MARK: - Home Controls
private struct HomeControls: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int
    let isReadyToRecord: Bool
    let cameraReady: Bool
    let showSetupTip: Bool
    let showStartTip: Bool
    let onSettings: () -> Void
    let onFlip: () -> Void
    let onRecord: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HomeHeader(onSettings: onSettings)
                .padding(.top, 4)

            GeometryReader { geo in
                let timerWidth = max(geo.size.width - 28, 0)

                ZStack {
                    VStack(spacing: 0) {
                        HomeTrafficTimer(
                            hours: $hours,
                            minutes: $minutes,
                            seconds: $seconds,
                            timerWidth: timerWidth,
                            isActive: isReadyToRecord
                        )
                        .padding(.top, 14)

                        if showSetupTip {
                            HomeTooltip(text: "Set up focus duration", pointer: .up)
                                .padding(.top, 8)
                        }

                        Spacer(minLength: 0)

                        if showStartTip {
                            HomeTooltip(text: "Start session when you're ready", pointer: .down)
                                .padding(.bottom, 14)
                        }

                        RecordButton(isReady: isReadyToRecord, action: onRecord)
                            .disabled(!isReadyToRecord || !cameraReady)
                            .padding(.bottom, 26)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)

                    // Flip-camera button, bottom-right.
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            FlipCameraButton(action: onFlip)
                                .padding(.trailing, 18)
                                .padding(.bottom, 30)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 92)
        }
    }
}

// MARK: - Record / Flip buttons

private struct RecordButton: View {
    let isReady: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 74, height: 74)
                Circle()
                    .fill(isReady ? Color.red : Color(white: 0.55))
                    .frame(width: 60, height: 60)
            }
            .animation(.easeInOut(duration: 0.2), value: isReady)
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isReady ? "Start focus session" : "Start focus session, unavailable")
        .accessibilityHint(isReady ? "Begins timelapse recording and focus timer" : "Set a focus duration first")
        .accessibilityInputLabels(["record", "start", "start session", "start recording", "start timelapse"])
        .accessibilityAddTraits(.isButton)
    }
}

private struct FlipCameraButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.rotate")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.8))
                .frame(width: 42, height: 42)
                .background(Color.white, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch camera")
        .accessibilityHint("Switches between front and back camera")
        .accessibilityInputLabels(["flip camera", "switch camera", "front camera", "back camera"])
    }
}

private struct HomeTooltip: View {
    enum Pointer { case up, down }

    let text: String
    let pointer: Pointer

    private let bubble = Color(white: 0.17)

    var body: some View {
        VStack(spacing: 0) {
            if pointer == .up {
                TooltipArrow(pointing: .up)
                    .fill(bubble)
                    .frame(width: 16, height: 7)
            }

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(bubble, in: Capsule())

            if pointer == .down {
                TooltipArrow(pointing: .down)
                    .fill(bubble)
                    .frame(width: 16, height: 7)
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        .accessibilityAddTraits(.isStaticText)
    }
}

private struct TooltipArrow: Shape {
    enum Direction { case up, down }
    let pointing: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch pointing {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Traffic-light duration picker

private struct HomeTrafficTimer: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int
    let timerWidth: CGFloat
    let isActive: Bool

    // Native Trafficframe ratio is 350 × 147.
    private var timerHeight: CGFloat { timerWidth * 147.0 / 350.0 }

    var body: some View {
        let col = timerWidth / 3

        ZStack {
            // Housing — explicit size, native ratio, so it never re-scales.
            Image("Trafficframe")
                .resizable()
                .frame(width: timerWidth, height: timerHeight)
                .allowsHitTesting(false)
                .accessibilityDecorative()

            // Rainbow glow INSIDE the housing — masked to the frame shape and pinned to
            // the top, sitting behind the dials, only once a duration is set.
            if isActive {
                Image("RainbowEffect")
                    .resizable()
                    .scaledToFill()
                    .frame(width: timerWidth, height: timerHeight * 0.6, alignment: .top)
                    .frame(width: timerWidth, height: timerHeight, alignment: .top)
                    .blur(radius: 8)
                    .opacity(0.85)
                    .mask(
                        Image("Trafficframe")
                            .resizable()
                            .frame(width: timerWidth, height: timerHeight)
                    )
                    .allowsHitTesting(false)
                    .accessibilityDecorative()
            }

            HStack(spacing: 0) {
                dial($hours, range: 0...23, column: col, unit: .hour)
                dial($minutes, range: 0...59, column: col, unit: .minute)
                dial($seconds, range: 0...59, column: col, unit: .second)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Focus duration")
            .accessibilityValue(
                AccessibilitySupport.spokenTime(hours: hours, minutes: minutes, seconds: seconds)
            )
            .frame(width: timerWidth, height: timerHeight, alignment: .top)
        }
        .frame(width: timerWidth, height: timerHeight)
    }

    private func dial(_ value: Binding<Int>, range: ClosedRange<Int>, column: CGFloat, unit: AccessibilitySupport.TimeUnit) -> some View {
        let shellW = column * 0.92
        let shellH = shellW * (129.0 / 117.0)   // native Trafficshell1 ratio
        let diameter = shellW * 0.62

        return ZStack {
            Image("Trafficshell1")
                .resizable()
                .frame(width: shellW, height: shellH)
                .allowsHitTesting(false)
                .accessibilityDecorative()

            HomeTimeDial(selected: value, range: range, diameter: diameter, unit: unit)
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .offset(y: -shellH * 0.15)   // align to the grille circle (upper ~42% of the shell)
        }
        .frame(width: column, height: timerHeight, alignment: .top)
        .padding(.top, timerHeight * 0.02)
    }
}

// MARK: - Single number dial


private struct HomeTimeDial: View {
    @Binding var selected: Int
    let range: ClosedRange<Int>
    let diameter: CGFloat
    let unit: AccessibilitySupport.TimeUnit

    // The values are repeated `reps` times so the wheel scrolls "endlessly" in both
    // directions and wraps (…23 → 00 → 01…). The list is bounded, and LazyVStack only
    // renders the few visible rows, so this stays cheap. Starting in the middle rep
    // leaves ~50 laps of room each way — far more than any real scroll.
    private let reps = 101
    @State private var scrollID: Int?

    private var values: [Int] { Array(range) }
    private var count: Int { values.count }
    private var total: Int { count * reps }

    /// The value shown at a given row index (wraps around the range).
    private func value(at index: Int) -> Int {
        values[((index % count) + count) % count]
    }

    /// The row index for `value` in the middle repetition (equal room to scroll each way).
    private func middleIndex(for value: Int) -> Int {
        (reps / 2) * count + (value - range.lowerBound)
    }

    var body: some View {
        let row = diameter * 0.5

        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(0..<total, id: \.self) { index in
                    let number = value(at: index)
                    let isSelected = number == selected
                    Text(String(format: "%02d", number))
                        .font(.system(
                            size: isSelected ? diameter * 0.42 : diameter * 0.27,
                            weight: .black,
                            design: .rounded
                        ))
                        .italic()
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.16))
                        .scaleEffect(isSelected ? 1 : 0.85)
                        .animation(.smooth(duration: 0.15), value: selected)
                        .frame(maxWidth: .infinity)
                        .frame(height: row)
                        .id(index)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, diameter * 0.2)
        }
        .frame(width: diameter, height: diameter)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollID)
        .defaultScrollAnchor(.center)
        .scrollClipDisabled()
        .clipped()
        .onAppear { if scrollID == nil { scrollID = middleIndex(for: selected) } }
        .onChange(of: scrollID) { _, new in
            guard let new else { return }
            let v = value(at: new)
            if v != selected { selected = v }
        }
        .onChange(of: selected) { _, new in
            // External change (e.g. reset) → jump to that value in the middle rep.
            if let id = scrollID, value(at: id) != new {
                scrollID = middleIndex(for: new)
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
        .timeDialAccessibility(selected: $selected, range: range, unit: unit)
    }
}

#Preview {
    HomePage()
        .environmentObject(SessionTimerViewModel())
        .environmentObject(SessionRecordingViewModel())
}
