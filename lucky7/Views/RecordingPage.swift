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
    
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        
        ZStack {
            
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack {
                HStack {
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
                                                
                                                // FIRST START
                                                hasStarted = true
                                                isRunning = true
                                                groupOffset = 70
                                                
                                            } else if isRunning {
                                                
                                                // PAUSE
                                                isRunning = false
                                                groupOffset = 0
                                                
                                            } else {
                                                
                                                // RESUME
                                                isRunning = true
                                                groupOffset = 70
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
                                
                                Button(action: {
                                    
                                    // surrenderScreen
                                    
                                }) {
                                    
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
        }
        .onDisappear {
            cameraManager.stopSession()
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
