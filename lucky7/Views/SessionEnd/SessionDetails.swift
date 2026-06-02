//
//  SessionDetails.swift
//  lucky7
//
//  Created by Kadek Belvanatha Gargita Satwikananda on 27/05/26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct SessionDetails: View {
    var sessionId: UUID
    var videoFrames: [UIImage] = []
    var onSave: (() -> Void)? = nil
    var onFlowComplete: (() -> Void)? = nil
    
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var sessionRecording: SessionRecordingViewModel
    @Query private var sessions: [Session]
    
    @State private var sessionTitle = ""
    @State private var sessionDescription = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var uploadedSnapshots: [UIImage] = []
    @State private var hasExitedFlow = false
    
    // filtering only 3 frames for snapshots
    private var displayFrame: [UIImage] {
        guard !videoFrames.isEmpty else { return [] }
        
        if videoFrames.count <= 3 {
            return videoFrames
        }
        
        let firstFrame = videoFrames.first!
        let middleFrame = videoFrames[videoFrames.count / 2]
        let lastFrame = videoFrames.last!
        
        return [firstFrame, middleFrame, lastFrame]
    }
    
    private var canSave: Bool {
        !sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !sessionDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !uploadedSnapshots.isEmpty
    }
    
    var body: some View {
        ZStack {
            Color("CanvasBlue")
                .ignoresSafeArea()
            
            Image("PatternBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .offset(y: -30)
            
            ScrollView {
                VStack (spacing: 4) {
                    
                    HStack {
                        Button(action: exitToHome) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    
                    SnapshotsView(images: displayFrame)
                        .padding(.top, 2)
                    
                    ZStack {
                        ForEach([CGPoint(x: -2, y: -2), CGPoint(x: 0, y: -2), CGPoint(x: 2, y: -2),
                                 CGPoint(x: -2, y: 0),                         CGPoint(x: 2, y: 0),
                                 CGPoint(x: -2, y: 2),  CGPoint(x: 0, y: 2),  CGPoint(x: 2, y: 2)], id: \.self) { p in
                            Text("How was \nyour drive?")
                                .foregroundColor(.white)
                                .offset(x: p.x, y: p.y)
                        }
                        Text("How was \nyour drive?")
                            .foregroundColor(.black)
                    }
                    .font(.custom("Special Gothic Expanded One", size: 35))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
                    
                    VStack(spacing: 24) {
                        CardInput(title: "TITLE", backgroundColor: .white) {
                            TextField("Give your session a title", text: $sessionTitle)
                                .multilineTextAlignment(.center)
                                .font(.custom("Special Gothic Expanded One", size: 14))
                                .foregroundColor(.black).opacity(1)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                        }

                        CardInput(title: "HOW DID IT GO?", backgroundColor: .white) {
                            TextField("What did you do during your session?\nHow did it go? How do you feel during and after the session?", text: $sessionDescription, axis: .vertical)
                                .lineLimit(4...8)
                                .multilineTextAlignment(.center)
                                .font(.custom("Special Gothic Expanded One", size: 14))
                                .foregroundColor(.black).opacity(1)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                        }
                        
                        CardInput(title: "ACTIVITIES SNAPSHOTS", backgroundColor: Color.blue.opacity(0.3)) {
                            PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .images) {
                                if uploadedSnapshots.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "camera.viewfinder")
                                            .font(.system(size: 35))
                                            .foregroundColor(.white)

                                        Text("Upload photo/ video of what you did")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(Array(uploadedSnapshots.enumerated()), id: \.offset) { _, img in
                                                Image(uiImage: img)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                                }
                            }
                        }
                        .onChange(of: pickerItems) { _, items in
                            Task {
                                var images: [UIImage] = []
                                for item in items {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let img = UIImage(data: data) {
                                        images.append(img)
                                    }
                                }
                                uploadedSnapshots = images
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(10)
                    
                    Button(action: {
                        if let session = sessions.first(where: { $0.id == sessionId }) {
                            session.title = sessionTitle
                            session.summary = sessionDescription
                            session.snapshotImages = uploadedSnapshots.compactMap {
                                $0.jpegData(compressionQuality: 0.8)
                            }
                            if let path = sessionRecording.finalVideoURL?.path {
                                session.wrappedVideoPath = path
                            }
                            try? context.save()
                        }
                        onSave?()
                    }) {
                        Text("SAVE SESSION")
                            .font(.custom("Special Gothic Expanded One", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(canSave ? Color.black : Color.black.opacity(0.3))
                            .cornerRadius(100)
                            .overlay(RoundedRectangle(cornerRadius: 100).stroke(Color.white, lineWidth: 2))
                            .shadow(color: .black, radius: 0, x: 0, y: 5)
                    }
                    .disabled(!canSave)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func exitToHome() {
        guard !hasExitedFlow else { return }
        hasExitedFlow = true
        onFlowComplete?()
    }
}

// MARK: - Reusable Custom Components

struct SnapshotsView: View {
    var images: [UIImage]
    
    var body: some View {
        ZStack {
            if images.count > 1 {
                Image(uiImage: images[1])
                    .resizable()
                    .scaledToFill()
                    .frame(width: 61, height: 81)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1))
                    .rotationEffect(.degrees(-11))
                    .shadow(color: .black, radius: 0, x: 0, y: 4)
                    .offset(x: -34, y: 5)
            }
            
            if images.count > 2 {
                Image(uiImage: images[2])
                    .resizable()
                    .scaledToFill()
                    .frame(width: 61, height: 81)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1))
                    .rotationEffect(.degrees(11))
                    .shadow(color: .black, radius: 0, x: 0, y: 4)
                    .offset(x: 34, y: 5)
            }
            
            if images.count > 0 {
                Image(uiImage: images[0])
                    .resizable()
                    .scaledToFill()
                    .frame(width: 68, height: 91)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1))
                    .shadow(color: .black, radius: 0, x: 0, y: 4)
                    .zIndex(1)
            }
        }
        .frame(height: 140)
    }
}

struct CardInput<Content: View>: View {
    let title: String
    var backgroundColor: Color
    let content: Content

    init(title: String, backgroundColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundColor
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 1))
                .padding(.top, 12)
            
            content
                .padding(.top, 12)
            
            Text(title)
                .font(.custom("Special Gothic Expanded One", size: 10))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black)
                .clipShape(Capsule())
                .offset(y: -2)
        }
    }
}

#Preview {
    let dummyFrames = ["dummySnapshot1", "dummySnapshot2", "dummySnapshot3"]
        .compactMap { UIImage(named: $0) }

    return SessionDetails(sessionId: UUID(), videoFrames: dummyFrames)
        .environmentObject(SessionRecordingViewModel())
        .modelContainer(for: Session.self, inMemory: true)
}
