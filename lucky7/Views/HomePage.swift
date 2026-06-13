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
    private let focusTransition = Animation.spring(response: 0.42, dampingFraction: 0.92, blendDuration: 0.08)

    private var isReadyToRecord: Bool {
        hours > 0 || minutes > 0 || seconds > 0
    }

    private var showSetupTip: Bool { !isReadyToRecord && !tipDurationSeen }
    private var showStartTip: Bool { isReadyToRecord && !tipStartSeen }

    var body: some View {
        ZStack {
            // 1a. Home background — fades out during a session.
            if !sessionActive {
                BackgroundPatternView(isTimerSet: isReadyToRecord)
                    .transition(.opacity)
            }

            // 1b. Session background (matches FullFocusScreen) — fades in around the frame.
            if sessionActive {
                RecordingBackground()
                    .transition(.opacity)
            }

            // 2. The single, persistent camera — ONE preview layer for the whole app so it
            //    never fights another layer for the feed. Its frame animates across three
            //    states: home card → full session card → focus circle.
            GeometryReader { geo in
                let circleSize: CGFloat = 164
                let isCircle = sessionActive && isFocusExpanded
                let homeScale = HomeDesign.scale(in: geo.size)
                let homeOrigin = HomeDesign.origin(in: geo.size, scale: homeScale)

                // Card insets (home vs in-session), measured from the screen edges. Active
                // frame: top sits 6pt below the countdown housing; bottom 6pt below pause.
                let activeTopInset = safeTop + 60
                let activeBottomInset = safeBottom + 28
                let activeHInset: CGFloat = 12

                let activeCardW = max(geo.size.width - activeHInset * 2, 0)
                let activeCardH = max(geo.size.height - activeTopInset - activeBottomInset, 0)
                let homeCardW = HomeDesign.camera.width * homeScale
                let homeCardH = HomeDesign.camera.height * homeScale

                let cardW = sessionActive ? activeCardW : homeCardW
                let cardH = sessionActive ? activeCardH : homeCardH
                let homeCenter = HomeDesign.center(of: HomeDesign.camera, origin: homeOrigin, scale: homeScale)

                let camW = isCircle ? circleSize : cardW
                let camH = isCircle ? circleSize : cardH
                let centerX = isCircle || sessionActive ? geo.size.width / 2 : homeCenter.x
                let centerY = isCircle ? safeTop + 168 : (sessionActive ? activeTopInset + activeCardH / 2 : homeCenter.y)
                let corner: CGFloat = isCircle ? circleSize / 2 : 30

                ZStack(alignment: .top) {
                    CameraPreview(session: sessionRecording.captureSession)
                        .frame(width: camW, height: camH)

                    if isReadyToRecord && !sessionActive && !isCircle {
                        Image("RainbowEffect")
                            .resizable()
                            .scaledToFill()
                            .frame(width: camW, height: 190 * homeScale)
                            .clipped()
                            .opacity(0.9)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: camW, height: camH)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .overlay {
                        if !isCircle {
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .strokeBorder(Color.black, lineWidth: sessionActive ? 3 : 2)
                        }
                    }
                    .position(x: centerX, y: centerY)
                    .animation(focusTransition, value: isFocusExpanded)
                    .animation(transition, value: sessionActive)
            }
            .ignoresSafeArea()

            // 3. Home controls (header + duration picker + record + flip) — fade out.
            if !sessionActive {
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
                .transition(.opacity)
            }

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
                // Mid-session the camera is already live — only warm it up for the idle
                // home preview, never underneath a recording.
                if isActiveTab && !sessionActive { sessionRecording.prepareCamera() }
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

private enum HomeDesign {
    static let size = CGSize(width: 402, height: 874)
    static let camera = CGRect(x: 10, y: 117, width: 382, height: 657)
    static let settings = CGRect(x: 16, y: 57, width: 40, height: 40)
    static let logo = CGRect(x: 126.5, y: 61, width: 149, height: 45)
    static let timer = CGRect(x: 26, y: 133, width: 350, height: 147)
    static let setupTip = CGRect(x: 140, y: 308, width: 122, height: 25)
    static let startTip = CGRect(x: 89.5, y: 513, width: 203, height: 29)
    static let recordCenter = CGPoint(x: 201, y: 703)
    static let flip = CGRect(x: 326, y: 683, width: 40, height: 40)

    static func scale(in size: CGSize) -> CGFloat {
        min(size.width / Self.size.width, size.height / Self.size.height)
    }

    static func origin(in size: CGSize, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: (size.width - Self.size.width * scale) / 2,
            y: (size.height - Self.size.height * scale) / 2
        )
    }

    static func center(of rect: CGRect, origin: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: origin.x + rect.midX * scale,
            y: origin.y + rect.midY * scale
        )
    }

    static func point(_ point: CGPoint, origin: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: origin.x + point.x * scale,
            y: origin.y + point.y * scale
        )
    }
}

// MARK: - Background

struct BackgroundPatternView: View {
    let isTimerSet: Bool

    @State private var pulse = false

    private let base = Color(red: 0 / 255, green: 96 / 255, blue: 190 / 255)   // #0060BE

    var body: some View {
        // Color is the flexible base; the pattern is an OVERLAY so a scaledToFill image
        // can't drive the view's width and blow up everything sized off it.
        base
            .overlay {
                if isTimerSet {
                    Image("group45")
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(pulse ? 1.04 : 0.98)
                        .opacity(pulse ? 1 : 0.72)
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                            value: pulse
                        )
                        .allowsHitTesting(false)
                }
            }
            .clipped()
            .ignoresSafeArea()
            .onAppear { if isTimerSet { pulse = true } }
            .onDisappear { pulse = false }
            .onChange(of: isTimerSet) { _, set in
                if set {
                    pulse = false
                    DispatchQueue.main.async { pulse = true }
                } else {
                    pulse = false
                }
            }
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
                .frame(width: 149, height: 45)

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
        .frame(height: 45)
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
        GeometryReader { geo in
            let scale = HomeDesign.scale(in: geo.size)
            let origin = HomeDesign.origin(in: geo.size, scale: scale)
            let recordCenter = HomeDesign.point(HomeDesign.recordCenter, origin: origin, scale: scale)

            ZStack {
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 28 * scale, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: HomeDesign.settings.width * scale, height: HomeDesign.settings.height * scale)
                }
                .buttonStyle(.plain)
                .position(HomeDesign.center(of: HomeDesign.settings, origin: origin, scale: scale))

                Image("Hrushhour")
                    .resizable()
                    .scaledToFit()
                    .frame(width: HomeDesign.logo.width * scale, height: HomeDesign.logo.height * scale)
                    .position(HomeDesign.center(of: HomeDesign.logo, origin: origin, scale: scale))

                HomeTrafficTimer(
                    hours: $hours,
                    minutes: $minutes,
                    seconds: $seconds,
                    timerWidth: HomeDesign.timer.width * scale
                )
                .position(HomeDesign.center(of: HomeDesign.timer, origin: origin, scale: scale))

                if showSetupTip {
                    HomePillTooltip(
                        text: "Set up focus duration",
                        width: HomeDesign.setupTip.width,
                        height: HomeDesign.setupTip.height,
                        scale: scale
                    )
                    .position(HomeDesign.center(of: HomeDesign.setupTip, origin: origin, scale: scale))
                }

                if showStartTip {
                    HomePillTooltip(
                        text: "Start session when you're ready",
                        width: HomeDesign.startTip.width,
                        height: HomeDesign.startTip.height,
                        scale: scale
                    )
                    .position(HomeDesign.center(of: HomeDesign.startTip, origin: origin, scale: scale))
                }

                RecordButton(isReady: isReadyToRecord, scale: scale, action: onRecord)
                    .disabled(!isReadyToRecord || !cameraReady)
                    .position(recordCenter)

                FlipCameraButton(scale: scale, action: onFlip)
                    .position(HomeDesign.center(of: HomeDesign.flip, origin: origin, scale: scale))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Record / Flip buttons

private struct RecordButton: View {
    let isReady: Bool
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4 * scale)
                    .frame(width: 74 * scale, height: 74 * scale)
                Circle()
                    .fill(isReady ? Color.red : Color(white: 0.55))
                    .frame(width: 60 * scale, height: 60 * scale)
            }
            .animation(.easeInOut(duration: 0.2), value: isReady)
            .shadow(color: .black.opacity(0.2), radius: 6 * scale, y: 3 * scale)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isReady ? "Start focus session" : "Start focus session, unavailable")
        .accessibilityHint(isReady ? "Begins timelapse recording and focus timer" : "Set a focus duration first")
        .accessibilityInputLabels(["record", "start", "start session", "start recording", "start timelapse"])
        .accessibilityAddTraits(.isButton)
    }
}

private struct FlipCameraButton: View {
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.rotate")
                .font(.system(size: 18 * scale, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.8))
                .frame(width: 40 * scale, height: 40 * scale)
                .background(Color.white.opacity(0.75), in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 4 * scale, y: 2 * scale)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch camera")
        .accessibilityHint("Switches between front and back camera")
        .accessibilityInputLabels(["flip camera", "switch camera", "front camera", "back camera"])
    }
}

// MARK: - Tooltip

private struct HomePillTooltip: View {
    let text: String
    let width: CGFloat
    let height: CGFloat
    let scale: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 10 * scale, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: width * scale, height: height * scale)
            .background(Color.black.opacity(0.8), in: Capsule())
    }
}

// MARK: - Traffic-light duration picker

private struct HomeTrafficTimer: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int
    let timerWidth: CGFloat

    // Native Trafficframe ratio is 350 × 147.
    private var timerHeight: CGFloat { timerWidth * 147.0 / 350.0 }

    var body: some View {
        let designScale = timerWidth / 350.0
        let shellGroupWidth = 319.67 * designScale
        let shellGroupHeight = 99.36 * designScale
        let shellSpacing = 10.8 * designScale
        let shellSlotWidth = (shellGroupWidth - shellSpacing * 2) / 3
        let shellTop = max((timerHeight - shellGroupHeight) / 2 - 6 * designScale, 0)

        ZStack(alignment: .top) {
            // Housing — explicit size, native ratio, so it never re-scales.
            Image("Trafficframe")
                .resizable()
                .frame(width: timerWidth, height: timerHeight)
                .allowsHitTesting(false)
                .accessibilityDecorative()

            HStack(spacing: shellSpacing) {
                dial($hours, range: 0...23, unit: .hour, shellSlotWidth: shellSlotWidth, shellHeight: shellGroupHeight)
                dial($minutes, range: 0...59, unit: .minute, shellSlotWidth: shellSlotWidth, shellHeight: shellGroupHeight)
                dial($seconds, range: 0...59, unit: .second, shellSlotWidth: shellSlotWidth, shellHeight: shellGroupHeight)
            }
            .frame(width: shellGroupWidth, height: shellGroupHeight)
            .padding(.top, shellTop)
        }
        .frame(width: timerWidth, height: timerHeight)
    }

    private func dial(
        _ value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: AccessibilitySupport.TimeUnit,
        shellSlotWidth: CGFloat,
        shellHeight: CGFloat
    ) -> some View {
        let lensDiameter = shellSlotWidth * 0.68
        let lensArtDiameter = shellSlotWidth * (87.27 / 99.36)
        let shellShadowHeight = shellSlotWidth * (26.69 / 99.36)
        let shellShadowWidth = shellSlotWidth * (99.41 / 99.36)
        let lensTop = (shellSlotWidth - lensArtDiameter) / 2
        let wheelTop = (shellSlotWidth - lensDiameter) / 2
        let frontLensTop = lensTop

        return ZStack(alignment: .top) {
            Image("TrafficShellShadow")
                .resizable()
                .frame(width: shellShadowWidth, height: shellShadowHeight)
                .offset(y: shellSlotWidth)
                .allowsHitTesting(false)

            Image("TrafficShellBg")
                .resizable()
                .frame(width: shellSlotWidth, height: shellSlotWidth)
                .allowsHitTesting(false)
                .accessibilityDecorative()

            Image("TrafficShell")
                .resizable()
                .frame(width: lensArtDiameter, height: lensArtDiameter)
                .offset(y: lensTop)
                .allowsHitTesting(false)

            HomeTimeDial(selected: value, range: range, diameter: lensDiameter, unit: unit)
                .frame(width: lensDiameter, height: lensDiameter)
                .clipShape(Circle())
                .offset(y: wheelTop)

            Image("TrafficShell")
                .resizable()
                .frame(width: lensArtDiameter, height: lensArtDiameter)
                .offset(y: frontLensTop)
                .opacity(0.28)
                .allowsHitTesting(false)

            Image("TrafficShell")
                .resizable()
                .frame(width: lensArtDiameter, height: lensArtDiameter)
                .offset(y: frontLensTop)
                .blendMode(.screen)
                .opacity(0.85)
                .allowsHitTesting(false)
        }
        .frame(width: shellSlotWidth, height: shellHeight)
    }
}

// MARK: - Single number dial


private struct HomeTimeDial: View {
    @Binding var selected: Int
    let range: ClosedRange<Int>
    let diameter: CGFloat
    let unit: AccessibilitySupport.TimeUnit

    @State private var scrollID: Int?

    private var values: [Int] { Array(range) }

    private func clamped(_ value: Int) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    var body: some View {
        let row = diameter * 0.5
        let centerPadding = max((diameter - row) / 2, 0)

        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(values, id: \.self) { number in
                    let isSelected = number == selected
                    Text("\(number)")
                        .font(.custom("Special Gothic Expanded One", size: isSelected ? diameter * 0.42 : diameter * 0.27))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.16))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: true, vertical: true)
                        .scaleEffect(isSelected ? 1 : 0.85)
                        .animation(.smooth(duration: 0.15), value: selected)
                        .frame(width: diameter, height: row)
                        .id(number)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, centerPadding)
        }
        .frame(width: diameter, height: diameter)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollID, anchor: .center)
        .scrollClipDisabled()
        .clipped()
        .onAppear { if scrollID == nil { scrollID = clamped(selected) } }
        .onChange(of: scrollID) { _, new in
            guard let new else { return }
            let value = clamped(new)
            if value != selected { selected = value }
        }
        .onChange(of: selected) { _, new in
            let value = clamped(new)
            if value != new {
                selected = value
            } else if scrollID != value {
                scrollID = value
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

