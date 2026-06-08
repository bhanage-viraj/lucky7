import SwiftUI
import AVFoundation

// MARK: - Main View

struct HomePage: View {
    @EnvironmentObject private var sessionRecording: SessionRecordingViewModel
    @EnvironmentObject private var sessionTimer: SessionTimerViewModel
    @EnvironmentObject private var recordingSession: RecordingSessionState

    var body: some View {
        ZStack {
            BackgroundPatternView()

            VStack(spacing: 0) {
                HomeHeaderView()
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                CameraCard(
                    session: sessionRecording.captureSession,
                    sessionRecording: sessionRecording,
                    isTimerRunning: sessionTimer.isRunning,
                    isRecording: sessionRecording.isRecording,
                    isReadyToRecord: sessionTimer.configuredTotalSeconds > 0,
                    onDurationChange: { hours, minutes, seconds in
                        sessionTimer.configure(hours: hours, minutes: minutes)
                    },
                    onRecordTap: startSession
                )
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            sessionRecording.prepareCamera()
        }
        .onChange(of: recordingSession.isActive) { _, isActive in
            if !isActive {
                sessionRecording.restoreHomePreview()
            }
        }
    }

    private func startSession() {
        guard !recordingSession.isActive,
              sessionTimer.configuredTotalSeconds > 0,
              sessionRecording.cameraReady else { return }

        recordingSession.requestPresentation()
    }
}

// MARK: - Header

private struct HomeHeaderView: View {
    var body: some View {
        HStack {
            Spacer()

            Image("Hrushhour")
                .resizable()
                .scaledToFit()
                .frame(height: 40)

            Spacer()
        }
        .overlay(alignment: .trailing) {
            Image(systemName: "gearshape")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .padding(.trailing, 24)
        }
    }
}

// MARK: - Camera Card

private struct CameraCard: View {
    let session: AVCaptureSession
    @ObservedObject var sessionRecording: SessionRecordingViewModel
    let isTimerRunning: Bool
    let isRecording: Bool
    let isReadyToRecord: Bool
    let onDurationChange: (Int, Int, Int) -> Void
    let onRecordTap: () -> Void

    private let aspectRatio: CGFloat = 382.0 / 657.0
    private let cornerRadius: CGFloat = 34

    var body: some View {
        ZStack {
            cardContent

            VStack(spacing: 0) {
                TrafficFrameOverlay(
                    isRunning: isTimerRunning,
                    onDurationChange: onDurationChange
                )
                .padding(.horizontal, 12)
                .padding(.top, 10)

                if !isRecording, !isReadyToRecord {
                    FocusDurationTooltip()
                        .padding(.top, 6)
                }

                Spacer()

                recordButton
                    .padding(.bottom, 36)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    flipCameraButton
                        .padding(.trailing, 18)
                        .padding(.bottom, 44)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private var cardContent: some View {
        ZStack {
            Color.black

            CameraPreview(session: session)
                .id(sessionRecording.previewRefreshID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.black, lineWidth: 2)
        }
    }

    private var recordButton: some View {
        let isRed = isReadyToRecord || isRecording

        return Button(action: onRecordTap) {
            Circle()
                .fill(isRed ? Color.red : Color(white: 0.45))
                .frame(width: 74, height: 74)
                .overlay {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                }
        }
        .disabled((!isReadyToRecord && !isRecording) || (!sessionRecording.cameraReady && !isRecording))
        .animation(.easeInOut(duration: 0.2), value: isRed)
    }

    private var flipCameraButton: some View {
        Button {
            sessionRecording.switchCamera()
        } label: {
            Image(systemName: "camera.rotate")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(.white, in: Circle())
        }
    }
}

// MARK: - Focus Duration Tooltip

private struct FocusDurationTooltip: View {
    private let bubbleColor = Color(white: 0.22)

    var body: some View {
        VStack(spacing: 0) {
            TooltipPointer()
                .fill(bubbleColor)
                .frame(width: 14, height: 7)

            Text("Set up focus duration")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(bubbleColor, in: Capsule())
        }
    }
}

private struct TooltipPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Traffic Frame

private struct TrafficFrameOverlay: View {
    let isRunning: Bool
    let onDurationChange: (Int, Int, Int) -> Void

    @State private var pickerHours = 0
    @State private var pickerMinutes = 0
    @State private var pickerSeconds = 0
    @State private var didInitialSync = false

    private let frameAspectRatio: CGFloat = 350.0 / 147.0
    private let shellHeightRatio: CGFloat = 129.0 / 147.0

    var body: some View {
        GeometryReader { geo in
            let columnWidth = geo.size.width / 3
            let shellHeight = geo.size.height * shellHeightRatio

            ZStack(alignment: .top) {
                Image("Trafficframe")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                HStack(spacing: -2) {
                    trafficShell(
                        selected: $pickerHours,
                        range: 0...23,
                        columnWidth: columnWidth,
                        shellHeight: shellHeight
                    )

                    trafficShell(
                        selected: $pickerMinutes,
                        range: 0...59,
                        columnWidth: columnWidth,
                        shellHeight: shellHeight
                    )

                    trafficShell(
                        selected: $pickerSeconds,
                        range: 0...59,
                        columnWidth: columnWidth,
                        shellHeight: shellHeight
                    )
                }
                .frame(width: geo.size.width, height: shellHeight)
                .offset(y: shellHeight*0.18)
            }
        }
        .aspectRatio(frameAspectRatio, contentMode: .fit)
        .disabled(isRunning)
        .onAppear {
            guard !didInitialSync else { return }
            didInitialSync = true
            syncDuration()
        }
        .onChange(of: pickerHours) { _, _ in syncDuration() }
        .onChange(of: pickerMinutes) { _, _ in syncDuration() }
        .onChange(of: pickerSeconds) { _, _ in syncDuration() }
    }

    private func trafficShell(
        selected: Binding<Int>,
        range: ClosedRange<Int>,
        columnWidth: CGFloat,
        shellHeight: CGFloat
    ) -> some View {
        let circleDiameter = min(columnWidth * 0.56, shellHeight * 0.68)

        return ZStack(alignment: .top) {
            Image("Trafficshell1")
                .resizable()
                .scaledToFit()
                .frame(width: columnWidth, height: shellHeight)
                .allowsHitTesting(false)

            ZStack(alignment: .center) {
                Circle()
                    .fill(Color.clear)
                    .frame(width: circleDiameter, height: circleDiameter)
                    .allowsHitTesting(false)

                NumberScroller(
                    selected: selected,
                    range: range,
                    compact: true,
                    wheelSize: circleDiameter
                )
            }
            .frame(width: circleDiameter, height: circleDiameter)
            .clipShape(Circle())
            .contentShape(Circle())
            .frame(width: columnWidth, height: shellHeight, alignment: .top)
            .padding(.top, shellHeight * 0.1)
        }
        .frame(width: columnWidth, height: shellHeight)
        .contentShape(Rectangle())
    }

    private func syncDuration() {
        onDurationChange(pickerHours, pickerMinutes, pickerSeconds)
    }
}

struct TrafficFrameCountdownOverlay: View, Equatable {
    let hours: Int
    let minutes: Int
    let seconds: Int

    private let frameAspectRatio: CGFloat = 350.0 / 147.0

    var body: some View {
        TrafficFrameCountdownLayout(hours: hours, minutes: minutes, seconds: seconds)
            .aspectRatio(frameAspectRatio, contentMode: .fit)
    }
}

private struct TrafficFrameCountdownLayout: View {
    let hours: Int
    let minutes: Int
    let seconds: Int

    private let shellHeightRatio: CGFloat = 129.0 / 147.0
    private let gothicFont = "Special Gothic Expanded One"

    var body: some View {
        GeometryReader { geo in
            let columnWidth = geo.size.width / 3
            let shellHeight = geo.size.height * shellHeightRatio
            let circleDiameter = min(columnWidth * 0.56, shellHeight * 0.68)
            let digitFontSize = circleDiameter * 0.35
            let digitTopPadding = shellHeight * 0.1

            ZStack(alignment: .top) {
                Image("Trafficframe")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .allowsHitTesting(false)

                HStack(spacing: -2) {
                    trafficShell(columnWidth: columnWidth, shellHeight: shellHeight)
                    trafficShell(columnWidth: columnWidth, shellHeight: shellHeight)
                    trafficShell(columnWidth: columnWidth, shellHeight: shellHeight)
                }
                .frame(width: geo.size.width, height: shellHeight)
                .offset(y: shellHeight * 0.18)
                .allowsHitTesting(false)

                HStack(spacing: -2) {
                    countdownDigit(value: hours, columnWidth: columnWidth, shellHeight: shellHeight, circleDiameter: circleDiameter, fontSize: digitFontSize, topPadding: digitTopPadding)
                    countdownDigit(value: minutes, columnWidth: columnWidth, shellHeight: shellHeight, circleDiameter: circleDiameter, fontSize: digitFontSize, topPadding: digitTopPadding)
                    countdownDigit(value: seconds, columnWidth: columnWidth, shellHeight: shellHeight, circleDiameter: circleDiameter, fontSize: digitFontSize, topPadding: digitTopPadding)
                }
                .frame(width: geo.size.width, height: shellHeight)
                .offset(y: shellHeight * 0.18)
            }
        }
    }

    private func trafficShell(columnWidth: CGFloat, shellHeight: CGFloat) -> some View {
        Image("Trafficshell1")
            .resizable()
            .scaledToFit()
            .frame(width: columnWidth, height: shellHeight)
    }

    private func countdownDigit(
        value: Int,
        columnWidth: CGFloat,
        shellHeight: CGFloat,
        circleDiameter: CGFloat,
        fontSize: CGFloat,
        topPadding: CGFloat
    ) -> some View {
        Text("\(value)")
            .font(.custom(gothicFont, size: fontSize))
            .foregroundStyle(.white)
            .monospacedDigit()
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(width: circleDiameter, height: circleDiameter)
            .frame(width: columnWidth, height: shellHeight, alignment: .top)
            .padding(.top, topPadding)
    }
}

// MARK: - Background

struct BackgroundPatternView: View {
    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()
            Image("group45")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
    }
}

