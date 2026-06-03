//
//  ScreenWakeLock.swift
//  lucky7
//

import UIKit

/// Prevents the device from auto-locking while a focus session is being recorded.
enum ScreenWakeLock {
    private(set) static var isActive = false

    static func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        UIApplication.shared.isIdleTimerDisabled = active
    }

    /// Always call when tearing down a session so Auto-Lock can resume.
    static func release() {
        setActive(false)
    }
}
