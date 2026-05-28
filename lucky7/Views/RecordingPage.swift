//
//  RecordingPage.swift
//  lucky7
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Main View

struct RecordingPage: View {
    @State private var isRunning = false
    @State private var hasStarted = false
    @State private var groupOffset: CGFloat = 0
    @State private var buttonText = "Start"
    @State private var showFullFocusScreen = false
    
    @StateObject private var cameraManager = RecordingCameraManager()
    
    var body: some View {
        
        ZStack {
            
            
            CameraPreview(session: cameraManager.session)
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
                        cameraManager.switchCamera()
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
                                        
                                        Text("2")
                                            .font(.custom("Special Gothic Expanded One", size: 34))
                                        
                                        Text("Hours")
                                            .font(.custom("Special Gothic Expanded One", size: 10))
                                    }
                                    .foregroundStyle(.white)
                                }
                                .scaleEffect(0.70)
                                
                                
                                TrafficShell {
                                    
                                    VStack(spacing: 2) {
                                        
                                        Text("30")
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
                                                isRunning = true
                                                groupOffset = 70
                                                
                                            } else if isRunning {
                                                
                                                isRunning = false
                                                groupOffset = 0
                                                
                                            } else {
                                                
                                                isRunning = true
                                                groupOffset = 70
                                            }
                                        }
                                        
                                    }) {
                                        
                                        VStack(spacing: 4) {
                                            
                                            Image(systemName:
                                                    !hasStarted
                                                  ? "play.fill"
                                                  : (isRunning ? "pause.fill" : "play.fill")
                                            )
                                            .font(.system(size: 20))
                                            
                                            Text(
                                                !hasStarted
                                                ? "START"
                                                : (isRunning ? "PAUSE" : "RESUME")
                                            )
                                            .font(.custom("Special Gothic Expanded One", size: 13))
                                        }
                                        .foregroundStyle(
                                            isRunning ? .yellow : .white
                                        )
                                    }
                                }
                                .scaleEffect(0.70)
                            }
                            .offset(x: 0, y: 80 + groupOffset)
                            if hasStarted && !isRunning {
                                
                                Button(action: {
                                    
                                    // surrenderScreen
                                    
                                }) {
                                    
                                    Image("End")
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
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .fullScreenCover(isPresented: $showFullFocusScreen) {
            FullFocusScreen()
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

class RecordingCameraManager: NSObject, ObservableObject {
    
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
