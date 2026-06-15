//
//  VideoOrientationHelper.swift
//  lucky7
//

import AVFoundation
import UIKit

enum VideoOrientationHelper {
    static func currentInterfaceOrientation() async -> UIInterfaceOrientation {
        // Always access UIApplication/UIScene on the main actor.
        return await MainActor.run { () -> UIInterfaceOrientation in
            interfaceOrientationFromApplication()
        }
    }

    static func currentInterfaceOrientationSync() -> UIInterfaceOrientation {
        if Thread.isMainThread {
            return interfaceOrientationFromApplication()
        }
        return DispatchQueue.main.sync {
            interfaceOrientationFromApplication()
        }
    }

    private static func interfaceOrientationFromApplication() -> UIInterfaceOrientation {
        let scenes = UIApplication.shared.connectedScenes
        let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
        let active = windowScenes.first { $0.activationState == .foregroundActive }
        return (active ?? windowScenes.first)?.interfaceOrientation ?? .portrait
    }

    /// Matches preview + recorded frames to how the user holds the phone.
    /// Uses `videoRotationAngle` (iOS 17+) so the preview and the writer
    /// transform read from the same value across devices and OS versions.
    static func applyToCaptureConnection(_ connection: AVCaptureConnection) async {
        let orientation = await currentInterfaceOrientation()
        let angle = rotationAngle(for: orientation)
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    static func rotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .portrait: return 270
        case .portraitUpsideDown: return 90
        case .landscapeLeft: return 0
        case .landscapeRight: return 180
        default: return 270
        }
    }

    /// Rotate/mirror sensor buffers so saved video is upright in the current interface orientation.
    ///
    /// The transform is applied to the encoded frame for display. The encoded frame has
    /// dimensions `W × H` (landscape sensor). After applying this transform, the content
    /// must land in `[0, H] × [0, W]` — the region that the player will show as a full
    /// portrait (or landscape) image after applying the rotation.
    static func writerTransform(
        bufferWidth: Int,
        bufferHeight: Int,
        cameraPosition: AVCaptureDevice.Position
    ) async -> CGAffineTransform {
        let orientation = await currentInterfaceOrientation()
        return writerTransform(
            bufferWidth: bufferWidth,
            bufferHeight: bufferHeight,
            cameraPosition: cameraPosition,
            orientation: orientation
        )
    }

    static func writerTransform(
        bufferWidth: Int,
        bufferHeight: Int,
        cameraPosition: AVCaptureDevice.Position,
        orientation: UIInterfaceOrientation
    ) -> CGAffineTransform {
        let width = CGFloat(bufferWidth)
        let height = CGFloat(bufferHeight)

        switch orientation {
        case .portrait:
            return portraitTransform(
                width: width, height: height, cameraPosition: cameraPosition, inverted: false
            )

        case .portraitUpsideDown:
            return portraitTransform(
                width: width, height: height, cameraPosition: cameraPosition, inverted: true
            )

        case .landscapeLeft:
            return landscapeTransform(
                width: width, height: height, cameraPosition: cameraPosition, flipped: false
            )

        case .landscapeRight:
            return landscapeTransform(
                width: width, height: height, cameraPosition: cameraPosition, flipped: true
            )

        default:
            return portraitTransform(
                width: width, height: height, cameraPosition: cameraPosition, inverted: false
            )
        }
    }

    // MARK: - Helpers

    /// Portrait (upright or upside-down) display. The encoded frame is W×H landscape.
    /// After the transform, content from `[0, W] × [0, H]` should land in
    /// `[0, H] × [0, W]` so the player's display rotation shows a full upright frame.
    private static func portraitTransform(
        width: CGFloat,
        height: CGFloat,
        cameraPosition: AVCaptureDevice.Position,
        inverted: Bool
    ) -> CGAffineTransform {
        // Back camera base: rotate 90° (CCW for upright, CW for upside-down) and
        // translate so the rotated content lands in the visible region.
        //   - upright:        R(90°) * T(0, -W)  →  (x, y) → (W - y, x)
        //   - upside-down:    T(0, W) * R(-90°)  →  (x, y) → (y, W - x)
        let base: CGAffineTransform = inverted
            ? CGAffineTransform(translationX: 0, y: width).rotated(by: -.pi / 2)
            : CGAffineTransform(rotationAngle: .pi / 2).translatedBy(x: 0, y: -width)

        guard cameraPosition == .front else { return base }

        // Front camera = base + horizontal mirror. After mirroring, the back-camera
        // content (which sat in [W-H, W] × [0, W]) lands in [-W, H-W] × [0, W]; a
        // post-mirror translation of +W brings it back to [0, H] × [0, W].
        // For upside-down, the content lands in [-H, 0] × [0, W] and needs +H.
        let postMirrorShift: CGFloat = inverted ? height : width
        return base
            .scaledBy(x: -1, y: 1)
            .translatedBy(x: postMirrorShift, y: 0)
    }

    /// Landscape (left or right) display. For a landscape-sensor buffer, the
    /// natural orientation already fills the encoded frame, so:
    ///   - landscapeLeft  → identity (back) or horizontal mirror (front)
    ///   - landscapeRight → R(180°) with translation (back) or + mirror (front)
    private static func landscapeTransform(
        width: CGFloat,
        height: CGFloat,
        cameraPosition: AVCaptureDevice.Position,
        flipped: Bool
    ) -> CGAffineTransform {
        if !flipped {
            // landscapeLeft: back = identity, front = horizontal mirror.
            guard cameraPosition == .front else { return .identity }
            return CGAffineTransform(scaleX: -1, y: 1)
                .translatedBy(x: width, y: 0)
        }

        // landscapeRight: rotate 180° around the frame center, then mirror for front.
        //   - back:  T(W, H) * R(180°)  →  (x, y) → (W - x, H - y)
        //   - front: back transform, then mirror + shift +W.
        let base = CGAffineTransform(translationX: width, y: height)
            .rotated(by: .pi)

        guard cameraPosition == .front else { return base }

        return base
            .scaledBy(x: -1, y: 1)
            .translatedBy(x: width, y: 0)
    }
}
