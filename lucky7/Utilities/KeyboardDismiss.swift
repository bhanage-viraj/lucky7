//
//  KeyboardDismiss.swift
//  lucky7
//
//  Global "tap anywhere outside a text field to dismiss the keyboard" support.
//

import SwiftUI
import UIKit

extension UIApplication {
    /// Installs a single tap recognizer on the key window so tapping anywhere
    /// outside a text field dismisses the keyboard.
    ///
    /// `cancelsTouchesInView` is `false` and the recognizer runs simultaneously
    /// with every other gesture, so it never swallows taps meant for buttons,
    /// lists, or scroll views — it just additionally ends editing.
    func enableTapToDismissKeyboard() {
        guard let window = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return }

        // Don't stack duplicate recognizers if this is called more than once.
        let alreadyInstalled = window.gestureRecognizers?
            .contains { $0 is KeyboardDismissTapGesture } ?? false
        guard !alreadyInstalled else { return }

        let tap = KeyboardDismissTapGesture(
            target: KeyboardDismissGestureDelegate.shared,
            action: #selector(KeyboardDismissGestureDelegate.dismissKeyboard)
        )
        tap.cancelsTouchesInView = false
        tap.delegate = KeyboardDismissGestureDelegate.shared
        window.addGestureRecognizer(tap)
    }
}

/// Marker subclass used only so we can detect an already-installed recognizer.
private final class KeyboardDismissTapGesture: UITapGestureRecognizer {}

/// Long-lived singleton acting as both the gesture target and delegate.
/// (UIGestureRecognizer holds its target/delegate without retaining them, so a
/// singleton keeps it alive for the app's lifetime.)
private final class KeyboardDismissGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissGestureDelegate()

    @objc func dismissKeyboard() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.endEditing(true) }
    }

    // Recognize alongside SwiftUI's own gestures so buttons / scrolling keep working.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    // Ignore taps that land on a text field/view — otherwise tapping a field to
    // focus it would immediately resign it again.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }
}
