// Views/FullScreenSession/FullFocusScreen.swift
// Placeholder for FullFocusScreen view

import SwiftUI
import AVFoundation
import Combine

struct FullFocusScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = FocusCameraManager()
    @EnvironmentObject private var countdown: SessionTimerViewModel
    @EnvironmentObject private var sessionRecording: SessionRecordingViewModel
    @State private var showCrashSession = false
    @State private var showEndSessionSheet = false
    
    var body: some View {
        NavigationStack{
            ZStack {
                Color("CanvasDarkGrey")
                    .ignoresSafeArea()
                
                Image("PatternBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .offset(x: -20, y: 2)
                
                VStack{
                    Spacer()
                    Image(.bottomBlur)
                }
                .ignoresSafeArea()
                
                VStack {
                    Color.clear
                        .frame(height: 24)
                    
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
                            .opacity(countdown.isRunning ? 0 : 1)
                        //
                        //                        MarqueeText(
                        //                            text: "Playing Dropdead by Olivia Rodrigo"
                        //                        )
                        
                    }
                    .padding(.horizontal, 12)
                    
                    Color.clear
                        .frame(height: 40)
                    
                    ZStack {
                        CameraPreviewView(session: camera.session)
                            .frame(width: 164, height: 164)
                            .background(.canvasDarkGrey)
                            .clipShape(Circle())
                            .onAppear { camera.start() }
                            .zIndex(2.0)
                        
                        Color.black
                            .frame(width: 164, height: 164)
                            .clipShape(Circle())
                            .offset(y: 10)
                            .zIndex(1.0)
                    }
                    .zIndex(3.0)
                    
                    ZStack(alignment: .center){
                        if (!countdown.isRunning) {
                            Image(.redYellowGreen)
                                .frame(height: 136)
                        }
                        
                        Image(.trafficLight)
                        
                        HStack {
                            Text("\(countdown.hours)")
                                .font(.custom("Special Gothic Expanded One", size: 34))
                                .frame(width: 104, height: 102)
                            
                            Text(String(format: "%02d", countdown.minutes))
                                .font(.custom("Special Gothic Expanded One", size: 34))
                                .frame(width: 104, height: 102)
                            
                            Text(String(format: "%02d", countdown.seconds))
                                    .font(.custom("Special Gothic Expanded One", size: 34))
                                    .frame(width: 110, height: 102)
                                    .clipped()
                                    .onTapGesture {
                                        countdown.toggle()
                                    }
                        }
                        .foregroundStyle(.white)
                        .frame(height: 136)
                        .zIndex(2.0)
                        .offset(y: -8)
                    }
                    .padding(.top, 36)
                    
                    Spacer()
                    
                    VStack(alignment: .center){
                        Text("Tips:")
                        Text("Don't forget to take break")
                    }
                    .opacity(0.5)
                    .foregroundStyle(.white)
                    
                    Spacer()
                    
//                    if (!countdown.isRunning) {
//                        Button {
//                            endSessionFromFullFocus()
//                        } label: {
//                            Text("END SESSION")
//                                .foregroundColor(.warningRed)
//                                .padding()
//                                .background(
//                                    Capsule()
//                                        .stroke(.warningRed)
//                                )
//                        }
//                    }
                    
                    HStack{
                        Button(action: {
                            showEndSessionSheet = true
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
                        .sheet(isPresented: $showEndSessionSheet) {
                            EndSessionSheet(
                                onEnd: {
                                    showEndSessionSheet = false
                                    endSessionFromFullFocus()
                                },
                                onCancel: {
                                    showEndSessionSheet = false
                                }
                            )
                            .presentationDetents([.height(220)])
                            .presentationDragIndicator(.visible)
                            .presentationCornerRadius(24)
                            .presentationBackground(.white)
                        }
                        
                        Spacer()

                        Button(action: {
                            countdown.toggle()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.75))
                                    .frame(width: 100, height: 100)
                                Image(systemName: countdown.isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.black)
                            }
                        }
                        
                        Spacer()

                        Button(action: {
                            dismiss()
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
                    
                    Color.clear
                        .frame(height: 16)
                }
            }
        }
        .onChange(of: countdown.showFinishSession) { _, show in
            if show {
                let wallClock = TimeInterval(countdown.elapsedSeconds)
                sessionRecording.stopRecordingAndExport(wallClockSeconds: wallClock) { }
            }
        }
        .fullScreenCover(isPresented: $countdown.showFinishSession) {
            FinishSessionScreen(onFlowComplete: {
                countdown.showFinishSession = false
                countdown.returnToHome()
            })
        }
        .fullScreenCover(isPresented: $showCrashSession) {
            CrashSessionScreen(onFlowComplete: {
                showCrashSession = false
                countdown.returnToHome()
            })
        }
    }
    
    private func endSessionFromFullFocus() {
        countdown.pause()
        let wallClock = TimeInterval(countdown.elapsedSeconds)
        sessionRecording.stopRecordingAndExport(wallClockSeconds: wallClock) {
            showCrashSession = true
        }
    }
}

#Preview {
    FullFocusScreen()
        .environmentObject(SessionTimerViewModel())
        .environmentObject(SessionRecordingViewModel())
}

// MARK: - MarqueText

struct MarqueeText: View {
    let text: String
    @State private var animate = false
    @State private var ready = false
    
    private let maxWidth: CGFloat = 180
    private let font = UIFont.systemFont(ofSize: 17)
    
    var textWidth: CGFloat {
        text.size(withAttributes: [.font: font]).width
    }
    
    var width: CGFloat {
        min(textWidth, maxWidth)
    }
    
    var body: some View {
        let shouldAnimate = textWidth > width
        
        ZStack(alignment: .leading) {
            if shouldAnimate {
                HStack(spacing: 40) {
                    Text(text)
                        .foregroundColor(.white)
                        .fixedSize()
                    Text(text)
                        .foregroundColor(.white)
                        .fixedSize()
                }
                .offset(x: animate ? -(textWidth + 40) : 0)
                .opacity(ready ? 1 : 0)
                .onAppear {
                    DispatchQueue.main.async {
                        ready = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(
                                .linear(duration: Double(textWidth) / 25)
                                .repeatForever(autoreverses: false)
                            ) {
                                animate = true
                            }
                        }
                    }
                }
            } else {
                Text(text)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(width: width, alignment: .leading)
        .clipped()
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color("CanvasDarkGrey"))
        )
    }
}

// MARK: - CameraUtil

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

class PreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard let session else { return }
            previewLayer.session = session
        }
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.videoGravity = .resizeAspectFill
    }
}

// MARK: - Camera Helper

class FocusCameraManager: ObservableObject {
    let session = AVCaptureSession()
    
    func start() {
        Task(priority: .background) {
            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .front          // or .back
            ),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input)
            else { return }
            
            session.beginConfiguration()
            session.addInput(input)
            session.commitConfiguration()
            session.startRunning()
        }
    }
}

// MARK: - End Session Sheet
struct EndSessionSheet: View {
    var onEnd: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.black)
                        .padding(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Title & Subtitle
            Text("End Session")
                .font(.title2.bold())
                .padding(.bottom, 8)
            
            Text("Ending now will stop recording\nand end your session early")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
            
            // Buttons
            HStack(spacing: 12) {
                // END button
                Button(action: onEnd) {
                    Text("END")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .stroke(.red, lineWidth: 1.5)
                        )
                }
                
                // CANCEL button
                Button(action: onCancel) {
                    Text("CANCEL")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(.black)
                        )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }
}
