//
//  RecordingPage.swift
//  lucky7
//

import SwiftUI
import AVFoundation

// MARK: - Main View

struct RecordingPage: View {
    @State private var hasStarted = false
    @State private var groupOffset: CGFloat = 0
    @State private var showFullFocusScreen = false
    @State private var showCrashSession = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionTimer: SessionTimerViewModel
    @EnvironmentObject private var sessionRecording: SessionRecordingViewModel

    var body: some View {

        ZStack {

            CameraPreview(session: sessionRecording.captureSession)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            
            VStack {
                VStack() {
                    
                    
                    
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
                                    .scaledToFit() // or .scaledToFill()
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
                                                hasStarted = true
                                                sessionRecording.startRecording(
                                                    plannedSessionSeconds: TimeInterval(sessionTimer.configuredTotalSeconds)
                                                )
                                                sessionTimer.start()
                                                groupOffset = 70
                                            } else if sessionTimer.isRunning {
                                                sessionTimer.pause()
                                                sessionRecording.pauseRecording()
                                                groupOffset = 0
                                            } else {
                                                sessionTimer.start()
                                                sessionRecording.resumeRecording()
                                                groupOffset = 70
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
                                        .foregroundStyle(
                                            sessionTimer.isRunning ? .yellow : .white
                                        )
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
        .onAppear {
            sessionRecording.prepareCamera()
        }
        .onDisappear {
            if !sessionRecording.isExporting {
                sessionRecording.stopCamera()
            }
        }
        .onChange(of: sessionTimer.showFinishSession) { _, show in
            if show {
                finalizeRecording()
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


#Preview {
    RecordingPage()
        .environmentObject(SessionTimerViewModel())
        .environmentObject(SessionRecordingViewModel())
}
