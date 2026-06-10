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
            let scenes = UIApplication.shared.connectedScenes
            let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
            let active = windowScenes.first { $0.activationState == .foregroundActive }
            return (active ?? windowScenes.first)?.interfaceOrientation ?? .portrait
        }
    }

    /// Matches preview + recorded frames to how the user holds the phone.
    static func applyToCaptureConnection(_ connection: AVCaptureConnection) async {
        let orientation = await currentInterfaceOrientation()
        // Use `videoOrientation` instead of rotation angles.
        // This avoids inverted mappings across iOS versions/devices.
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = captureVideoOrientation(from: orientation)
        }
    }

    static func rotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        // This mapping matches what users expect visually:
        // holding phone upright (portrait) should produce an upright preview/video.
        case .portrait: return 270
        case .portraitUpsideDown: return 90
        case .landscapeLeft: return 0
        case .landscapeRight: return 180
        default: return 270
        }
    }

    static func captureVideoOrientation(from orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .portrait
        }
    }

    /// Rotate/mirror sensor buffers so saved video is upright in the current interface orientation.
    static func writerTransform(
        bufferWidth: Int,
        bufferHeight: Int,
        cameraPosition: AVCaptureDevice.Position
    ) async -> CGAffineTransform {
        let orientation = await currentInterfaceOrientation()
        let width = CGFloat(bufferWidth)
        let height = CGFloat(bufferHeight)
        let isLandscapeBuffer = bufferWidth > bufferHeight

        switch orientation {
        case .portrait:
            if isLandscapeBuffer {
                return portraitUpFromLandscapeBuffer(
                    width: width,
                    height: height,
                    cameraPosition: cameraPosition
                )
            }
            if cameraPosition == .front {
                return CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -width, y: 0)
            }
            return .identity

        case .portraitUpsideDown:
            if isLandscapeBuffer {
                return portraitDownFromLandscapeBuffer(
                    width: width,
                    height: height,
                    cameraPosition: cameraPosition
                )
            }
            if cameraPosition == .front {
                return CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -width, y: 0)
                    .rotated(by: .pi)
            }
            return CGAffineTransform(rotationAngle: .pi)

        case .landscapeLeft:
            if cameraPosition == .front {
                return CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -width, y: 0)
            }
            return .identity

        case .landscapeRight:
            if isLandscapeBuffer {
                return CGAffineTransform(rotationAngle: .pi)
            }
            return CGAffineTransform(rotationAngle: .pi)

        default:
            return portraitUpFromLandscapeBuffer(
                width: width,
                height: height,
                cameraPosition: cameraPosition
            )
        }
    }

    // MARK: - Portrait from landscape sensor buffer (typical iPhone)

    private static func portraitUpFromLandscapeBuffer(
        width: CGFloat,
        height: CGFloat,
        cameraPosition: AVCaptureDevice.Position
    ) -> CGAffineTransform {
        // Standard portrait fix for landscape sensor buffers:
        // rotate +90° then translate up by -width.
        let base = CGAffineTransform(rotationAngle: .pi / 2)
            .translatedBy(x: 0, y: -width)

        if cameraPosition == .front {
            // Mirror for selfie camera after rotation.
            return base
                .scaledBy(x: -1, y: 1)
                .translatedBy(x: -height, y: 0)
        }

        return base
    }

    private static func portraitDownFromLandscapeBuffer(
        width: CGFloat,
        height: CGFloat,
        cameraPosition: AVCaptureDevice.Position
    ) -> CGAffineTransform {
        // Upside-down portrait: rotate -90° then translate left by -height.
        let base = CGAffineTransform(rotationAngle: -.pi / 2)
            .translatedBy(x: -height, y: 0)

        if cameraPosition == .front {
            return base
                .scaledBy(x: -1, y: 1)
                .translatedBy(x: -width, y: 0)
        }

        return base
    }
}
