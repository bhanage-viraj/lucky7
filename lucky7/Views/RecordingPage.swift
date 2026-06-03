//
//  RecordingPage.swift
//  lucky7
//

import SwiftUI
import SwiftData
import AVFoundation
import Combine

// MARK: - Main View

struct RecordingPage: View {
    @State private var isRunning = false
    @State private var hasStarted = false
    @State private var groupOffset: CGFloat = 0
    @State private var buttonText = "Start"

    @StateObject private var cameraManager = CameraManager()

    #if os(iOS)
    @EnvironmentObject private var focusController: FocusViewModel
    #endif

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @State private var sessionId = UUID()
    @State private var pendingPrompt: PendingPrompt?
    @State private var showRecords = false
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

    var body: some View {

        ZStack {

            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                HStack {
                    Button(action: { showRecords = true }) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    .padding()

                    Spacer()

                    Button(action: {
                        cameraManager.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    .padding()
                }

                Spacer()
                Group {

                    VStack(spacing: 20) {

                        ZStack {

                            Image("group30")
                                .offset(x: 0, y: 80 + groupOffset)

                            Image("Rectangle39")
                                .offset(x: 0, y: 200 + groupOffset)

                            Image("Frame35")
                                .offset(x: 0, y: 80 + groupOffset)

                            HStack(spacing: -30) {

                                TrafficShell {
                                    Text("2\nHours")
                                        .foregroundColor(.white)
                                }
                                .scaleEffect(0.70)

                                TrafficShell {
                                    Text("30\nMinutes")
                                        .foregroundColor(.white)
                                }
                                .scaleEffect(0.70)


                                TrafficShell {

                                    Button(action: {

                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {

                                            if !hasStarted {

                                                // FIRST START — engage shield
                                                hasStarted = true
                                                isRunning = true
                                                groupOffset = 70
                                                #if os(iOS)
                                                focusController.engage()
                                                #endif

                                            } else if isRunning {

                                                // PAUSE
                                                isRunning = false
                                                groupOffset = 0
                                                #if os(iOS)
                                                focusController.pause()
                                                #endif

                                            } else {

                                                // RESUME — reblock the distraction and roll on
                                                isRunning = true
                                                groupOffset = 70
                                                #if os(iOS)
                                                focusController.resume()
                                                closeOpenDistractions()
                                                #endif
                                            }
                                        }

                                    }) {

                                        Text(
                                            !hasStarted
                                            ? "Start"
                                            : (isRunning ? "Pause" : "Resume")
                                        )
                                        .foregroundStyle(.white)
                                    }
                                }
                                .scaleEffect(0.70)
                            }.offset(x:0, y: 80+groupOffset)
                            if hasStarted && !isRunning {

                                Button(action: endSession) {

                                    Text("End")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(width: 140, height: 50)
                                        .background(Color.red)
                                        .cornerRadius(18)
                                }
                                .offset(y: 200 + groupOffset)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            cameraManager.checkPermissions()
            checkPendingEvents()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkPendingEvents()
            }
        }
        #if os(iOS)
        // when a distraction auto-pauses the session, reflect it in the button
        .onChange(of: focusController.isRunning) { _, running in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isRunning = running
                groupOffset = running ? 70 : 0
            }
            if running { unlock = nil }   // back to focus → drop the unlock pill
        }
        #endif
        .onDisappear {
            cameraManager.stopSession()
            #if os(iOS)
            focusController.release()
            #endif
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
                    // leave endTime open — it's set when they Resume, so the
                    // distracted duration = time away from focus
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
        .sheet(isPresented: $showRecords) {
            BreakRecordsView()
        }
        .toolbar(.hidden, for: .tabBar)
        .overlay {
            #if os(iOS)
            if let u = unlock {
                BreakUnlockOverlay(appName: u.appName, onFinished: { unlock = nil })
                    .id(u.id)   // fresh animation per break
            }
            #endif
        }
    }

    private func endSession() {
        closeOpenDistractions()
        #if os(iOS)
        focusController.release()
        #endif
        SharedJailbreakStore.removeAll()
        cameraManager.stopSession()
        dismiss()
    }

    // stamp endTime on any break still open, so its distracted duration is recorded
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

        // don't prompt for this break again, but keep the action events for the count
        SharedJailbreakStore.markBreakHandled(pair.action.occurredAt)
        pendingPrompt = PendingPrompt(distraction: distraction, tokenDataToClear: tokenData)
        #endif
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

        // Ensure preview layer fills the view
        previewLayer.frame = bounds

        // Update video orientation to match interface orientation
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = currentVideoOrientation()
        }
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            switch scene.interfaceOrientation {
            case .portrait: return .portrait
            case .portraitUpsideDown: return .portraitUpsideDown
            case .landscapeLeft: return .landscapeLeft
            case .landscapeRight: return .landscapeRight
            default: return .portrait
            }
        }
        return .portrait
    }
}


// MARK: - Camera Manager

class CameraManager: NSObject, ObservableObject {

    @Published var cameraPosition: AVCaptureDevice.Position = .front
    let session = AVCaptureSession()

    func checkPermissions() {

        switch AVCaptureDevice.authorizationStatus(for: .video) {

        case .authorized:
            setupCamera()

        case .notDetermined:

            AVCaptureDevice.requestAccess(for: .video) { granted in

                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                }
            }

        default:
            print("Camera permission denied")
        }
    }


    func setupCamera() {
        configureSession(position: cameraPosition)
    }

    private func configureSession(position: AVCaptureDevice.Position) {

        session.beginConfiguration()

        // Remove existing inputs
        for input in session.inputs {
            session.removeInput(input)
        }

        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("Camera input error:", error)
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func switchCamera() {
        cameraPosition = (cameraPosition == .back) ? .front : .back
        DispatchQueue.main.async {
            self.configureSession(position: self.cameraPosition)
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}

#Preview {
    RecordingPage()
}
