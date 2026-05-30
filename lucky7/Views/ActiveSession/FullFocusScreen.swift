// Views/FullScreenSession/FullFocusScreen.swift
// Placeholder for FullFocusScreen view

import SwiftUI
import AVFoundation
import Combine

struct FullFocusScreen: View {
    @StateObject private var camera = FocusCameraManager()
    @StateObject private var countdown = TimerManager()
    
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
                        Color.clear
                            .frame(width: 48, height: 48)
                        
                        Spacer()
                        
                        MarqueeText(
                            text: "Playing Dropdead by Olivia Rodrigo"
                        )
                        
                        Spacer()
                        
                        Button {
                            
                        } label: {
                            Image(systemName: "arrow.up.right.and.arrow.down.left")
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(
                                    Capsule()
                                        .fill(Color("CanvasDarkGrey"))
                                )
                        }
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
                            VStack {
                                Text("\(countdown.hours)")
                                    .font(.custom("Special Gothic Expanded One", size: 34))
                                Text("Hours")
                                    .font(.custom("Special Gothic Expanded One", size: 10))
                            }
                            .frame(width: 104, height: 102)
                            
                            VStack {
                                Text(String(format: "%02d", countdown.minutes))
                                    .font(.custom("Special Gothic Expanded One", size: 34))
                                Text("Minutes")
                                    .font(.custom("Special Gothic Expanded One", size: 10))
                            }
                            .frame(width: 104, height: 102)
                            
                            VStack {
                                Image(systemName: countdown.isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20))
                                Color.clear
                                    .frame(height: 1)
                                Text(countdown.isRunning ? "PAUSE" : "RESUME")
                                    .font(.custom("Special Gothic Expanded One", size: 13))
                            }
                            .foregroundStyle(countdown.isRunning ? .yellow : .white)
                            .frame(width: 110, height: 102)
                            .clipped()
                            .onTapGesture {
                                countdown.isRunning ? countdown.pause() : countdown.start()
                            }
                        }
                        .foregroundStyle(.white)
                        .opacity(0.4)
                        .frame(height: 136)
                        .zIndex(2.0)
                        .offset(y: -8)
                        .onAppear {
                            countdown.set(hours: 2, minutes: 30)
                            countdown.start()
                        }
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
                    
                    if (!countdown.isRunning) {
                        Button {
                            
                        } label: {
                            Text("END SESSION")
                                .foregroundColor(.warningRed)
                                .padding()
                                .background(
                                    Capsule()
                                        .stroke(.warningRed)
                                )
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    FullFocusScreen()
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

// MARK: - TimeManager

class TimerManager: ObservableObject {
    @Published var hours: Int = 0
    @Published var minutes: Int = 0
    @Published var seconds: Int = 0
    @Published var isRunning: Bool = false
    
    private var timer: Timer?
    private var totalSeconds: Int = 0
    
    // Set the countdown duration
    func set(hours: Int, minutes: Int) {
        self.totalSeconds = (hours * 3600) + (minutes * 60)
        self.hours = hours
        self.minutes = minutes
        self.seconds = 0
    }
    
    func start() {
        guard totalSeconds > 0 else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.tick()
        }
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
    }
    
    func reset() {
        timer?.invalidate()
        isRunning = false
        totalSeconds = 0
        hours = 0
        minutes = 0
        seconds = 0
    }
    
    private func tick() {
        guard totalSeconds > 0 else {
            pause()
            return
        }
        totalSeconds -= 1
        hours   = totalSeconds / 3600
        minutes = (totalSeconds % 3600) / 60
        seconds = totalSeconds % 60
    }
    
    deinit {
        timer?.invalidate()
    }
}
