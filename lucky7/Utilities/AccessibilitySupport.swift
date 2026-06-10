//
//  AccessibilitySupport.swift
//  lucky7
//
//  Shared VoiceOver and Voice Control helpers.
//

import SwiftUI
import UIKit

enum AccessibilitySupport {

    // MARK: - Announcements

    static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    // MARK: - Spoken durations

    static func spokenTime(hours: Int, minutes: Int, seconds: Int) -> String {
        var parts: [String] = []
        if hours > 0 {
            parts.append(hours == 1 ? "1 hour" : "\(hours) hours")
        }
        if minutes > 0 {
            parts.append(minutes == 1 ? "1 minute" : "\(minutes) minutes")
        }
        if seconds > 0 || parts.isEmpty {
            parts.append(seconds == 1 ? "1 second" : "\(seconds) seconds")
        }
        return parts.joined(separator: ", ")
    }

    static func spokenCountdown(hours: Int, minutes: Int, seconds: Int) -> String {
        if hours == 0 && minutes == 0 && seconds == 0 {
            return "Time is up"
        }
        return "\(spokenTime(hours: hours, minutes: minutes, seconds: seconds)) remaining"
    }

    static func spokenPaddedComponent(_ value: Int, unit: TimeUnit) -> String {
        let count = value
        switch unit {
        case .hour:
            return count == 1 ? "1 hour" : "\(count) hours"
        case .minute:
            return count == 1 ? "1 minute" : "\(count) minutes"
        case .second:
            return count == 1 ? "1 second" : "\(count) seconds"
        }
    }

    enum TimeUnit {
        case hour, minute, second

        var label: String {
            switch self {
            case .hour: return "Hours"
            case .minute: return "Minutes"
            case .second: return "Seconds"
            }
        }

        var inputLabels: [String] {
            switch self {
            case .hour: return ["hours", "hour"]
            case .minute: return ["minutes", "minute", "mins"]
            case .second: return ["seconds", "second", "secs"]
            }
        }
    }

    static func recordingStateLabel(isRecording: Bool, isPaused: Bool) -> String {
        if isPaused { return "Recording paused" }
        if isRecording { return "Recording in progress" }
        return "Not recording"
    }

    static func cameraPreviewValue(
        isRecording: Bool,
        isPaused: Bool,
        frameCount: Int,
        remainingHours: Int,
        remainingMinutes: Int,
        remainingSeconds: Int
    ) -> String {
        var parts: [String] = [recordingStateLabel(isRecording: isRecording, isPaused: isPaused)]
        if isRecording || isPaused {
            parts.append("\(frameCount) frames captured")
            parts.append(spokenCountdown(hours: remainingHours, minutes: remainingMinutes, seconds: remainingSeconds))
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - View modifiers

extension View {

    /// Hides decorative visuals from VoiceOver and Voice Control.
    func accessibilityDecorative() -> some View {
        accessibilityHidden(true)
    }

    /// Groups child elements into one accessibility element with a combined label.
    func accessibilityGrouped(label: String, hint: String? = nil, value: String? = nil) -> some View {
        modifier(AccessibilityGroupedModifier(label: label, hint: hint, value: value))
    }
}

private struct AccessibilityGroupedModifier: ViewModifier {
    let label: String
    let hint: String?
    let value: String?

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .modifier(OptionalAccessibilityHint(hint: hint))
            .modifier(OptionalAccessibilityValue(value: value))
    }
}

private struct OptionalAccessibilityHint: ViewModifier {
    let hint: String?
    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty { content.accessibilityHint(hint) }
        else { content }
    }
}

private struct OptionalAccessibilityValue: ViewModifier {
    let value: String?
    func body(content: Content) -> some View {
        if let value, !value.isEmpty { content.accessibilityValue(value) }
        else { content }
    }
}

/// Adjustable dial for custom scroll-wheel time pickers.
struct TimeDialAccessibilityModifier: ViewModifier {
    @Binding var selected: Int
    let range: ClosedRange<Int>
    let unit: AccessibilitySupport.TimeUnit

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(unit.label)
            .accessibilityValue(String(format: "%02d", selected))
            .accessibilityHint("Swipe up or down to adjust")
            .accessibilityInputLabels(unit.inputLabels)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    selected = min(selected + 1, range.upperBound)
                case .decrement:
                    selected = max(selected - 1, range.lowerBound)
                @unknown default:
                    break
                }
            }
    }
}

extension View {
    func timeDialAccessibility(selected: Binding<Int>, range: ClosedRange<Int>, unit: AccessibilitySupport.TimeUnit) -> some View {
        modifier(TimeDialAccessibilityModifier(selected: selected, range: range, unit: unit))
    }
}

/// Announces a message when a boolean binding becomes true.
struct AccessibilityAnnouncementOnChange: ViewModifier {
    let isActive: Bool
    let message: String
    @State private var didAnnounce = false

    func body(content: Content) -> some View {
        content
            .onChange(of: isActive) { _, active in
                if active, !didAnnounce {
                    didAnnounce = true
                    AccessibilitySupport.announce(message)
                } else if !active {
                    didAnnounce = false
                }
            }
    }
}

extension View {
    func accessibilityAnnounce(when isActive: Bool, message: String) -> some View {
        modifier(AccessibilityAnnouncementOnChange(isActive: isActive, message: message))
    }
}
