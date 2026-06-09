//
//  SessionDetails.swift
//  lucky7
//
//  Created by Kadek Belvanatha Gargita Satwikananda on 27/05/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

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
    @State private var showImageSourceDialog = false
    @State private var showCamera = false
    @State private var showLibrary = false

    private let maxSnapshots = 6
    private let maxTitleLength = 30

    /// Dark navy fill for the SAVE button (matches the design mock-up).
    private let saveButtonColor = Color(red: 30 / 255, green: 58 / 255, blue: 95 / 255)

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

    private func addSnapshot(_ image: UIImage) {
        guard uploadedSnapshots.count < maxSnapshots else { return }
        uploadedSnapshots.append(downscaled(image))
    }

    /// Shrinks large photos so storing/decoding several of them doesn't spike memory.
    private func downscaled(_ image: UIImage, maxDimension: CGFloat = 1080) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else { return image }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
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
                VStack(spacing: 24) {
                    sessionCard
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Card

    private var sessionCard: some View {
        PatternBorderedCard {
            VStack(spacing: 22) {
                SnapshotsView(images: displayFrame)

                Text("How was your session?")
                    .font(.custom("Special Gothic Expanded One", size: 22))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                LabeledField(title: "TITLE") {
                    TextField("Give your session a title", text: $sessionTitle)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .formFieldStyle()
                        .onChange(of: sessionTitle) { _, newValue in
                            if newValue.count > maxTitleLength {
                                sessionTitle = String(newValue.prefix(maxTitleLength))
                            }
                        }
                }

                LabeledField(title: "HOW DID IT GO?") {
                    TextField(
                        "How do you feel during and after the session?",
                        text: $sessionDescription,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    .formFieldStyle()
                }

                LabeledField(title: "ACTIVITIES SNAPSHOTS") {
                    snapshotsField
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 32)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Snapshots field

    @ViewBuilder
    private var snapshotsField: some View {
        Group {
            if uploadedSnapshots.isEmpty {
                Button {
                    showImageSourceDialog = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundColor(.black)

                        Text("Add Photos/Video")
                            .font(.custom("Special Gothic Expanded One", size: 14))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
                }
                .formFieldStyle()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(uploadedSnapshots.enumerated()), id: \.offset) { index, img in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        uploadedSnapshots.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black)
                                            .frame(width: 36, height: 36)   // big enough tap target
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                        }

                        if uploadedSnapshots.count < maxSnapshots {
                            Button {
                                showImageSourceDialog = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 80, height: 80)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black.opacity(0.06))
                                    )
                            }
                        }
                    }
                    .padding(12)
                }
                .formFieldStyle()
            }
        }
        .confirmationDialog("Add a snapshot", isPresented: $showImageSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showLibrary,
            selection: $pickerItems,
            maxSelectionCount: max(1, maxSnapshots - uploadedSnapshots.count),
            matching: .images
        )
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                addSnapshot(image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var newImages: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        newImages.append(img)
                    }
                }
                await MainActor.run {
                    for img in newImages { addSnapshot(img) }
                    pickerItems = []
                }
            }
        }
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button(action: saveSession) {
            Text("SAVE")
                .font(.custom("Special Gothic Expanded One", size: 16))
                .foregroundColor(.white.opacity(canSave ? 1 : 0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(canSave ? saveButtonColor : saveButtonColor.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .shadow(color: .black.opacity(0.7), radius: 0, x: 0, y: 4)
        }
        .disabled(!canSave)
    }

    private func saveSession() {
        var sessionDuration: TimeInterval = 0
        if let session = sessions.first(where: { $0.id == sessionId }) {
            session.title = sessionTitle
            session.summary = sessionDescription
            session.snapshotImages = uploadedSnapshots.compactMap {
                $0.jpegData(compressionQuality: 0.8)
            }
            if let path = sessionRecording.finalVideoURL?.path {
                session.wrappedVideoPath = path
            }
            if let rawPath = sessionRecording.rawClipURL?.path {
                session.rawClipPath = rawPath
            }
            sessionDuration = session.actualDuration
            try? context.save()
        }
        // Re-render the wrap with the chosen title (the first export ran before the title
        // existed). FinishSessionScreen's finalVideoURL observer then updates wrappedVideoPath.
        // Burn in the session's actual focus duration as the hero number.
        let trimmed = sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        sessionRecording.reexportWithTitle(
            trimmed.isEmpty ? "Untitled session" : trimmed,
            durationSeconds: sessionDuration
        )
        onSave?()
    }
}

// MARK: - Camera Capture

/// Wraps `UIImagePickerController` so a snapshot can be taken straight from the camera.
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Reusable Custom Components

/// White card with a rounded-rectangle clip mask and the `BlackWhitePattern`
/// checkerboard strip pinned to the chosen edges (ticket-style border).
struct PatternBorderedCard<Content: View>: View {
    var edges: Set<VerticalEdge>
    var cornerRadius: CGFloat
    let content: Content

    init(
        edges: Set<VerticalEdge> = [.top, .bottom],
        cornerRadius: CGFloat = 28,
        @ViewBuilder content: () -> Content
    ) {
        self.edges = edges
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .overlay(alignment: .top) {
                if edges.contains(.top) {
                    Image("BlackWhitePattern")
                        .resizable()
                        .frame(height: 12)
                }
            }
            .overlay(alignment: .bottom) {
                if edges.contains(.bottom) {
                    Image("BlackWhitePattern")
                        .resizable()
                        .frame(height: 12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.black, lineWidth: 2)
            )
    }
}

/// A left-aligned uppercase label sitting above a form control.
struct LabeledField<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Special Gothic Expanded One", size: 11))
                .foregroundColor(.black)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// White rounded-rectangle field with a thin dark outline.
    func formFieldStyle() -> some View {
        background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.35), lineWidth: 1.5)
        )
    }
}

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
                    .shadow(color: .black, radius: 0, x: 0, y: 4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
                    .rotationEffect(.degrees(-11))
                    .offset(x: -34, y: 5)
            }

            if images.count > 2 {
                Image(uiImage: images[2])
                    .resizable()
                    .scaledToFill()
                    .frame(width: 61, height: 81)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black, radius: 0, x: 0, y: 4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
                    .rotationEffect(.degrees(11))
                    .offset(x: 34, y: 5)
            }

            if images.count > 0 {
                Image(uiImage: images[0])
                    .resizable()
                    .scaledToFill()
                    .frame(width: 68, height: 91)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black, radius: 0, x: 0, y: 5)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
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
                .cornerRadius(20)
                .shadow(color: .black, radius: 0, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 1))
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
