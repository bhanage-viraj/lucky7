import Foundation
import Combine

@MainActor
final class SessionTimerViewModel: ObservableObject {
    @Published var hours: Int = 2
    @Published var minutes: Int = 30
    @Published var seconds: Int = 0
    @Published var isRunning: Bool = false
    @Published var showFinishSession: Bool = false
    @Published var requestReturnToHome: Bool = false

    private var timer: Timer?
    private var totalSeconds: Int = 2 * 3600 + 30 * 60
    private(set) var configuredTotalSeconds: Int = 2 * 3600 + 30 * 60

    var elapsedSeconds: Int {
        let remaining = (hours * 3600) + (minutes * 60) + seconds
        return max(configuredTotalSeconds - remaining, 0)
    }

    func configure(hours: Int, minutes: Int) {
        pause()
        showFinishSession = false

        let clampedHours = min(max(hours, 0), 23)
        let clampedMinutes = min(max(minutes, 1), 59)

        self.hours = clampedHours
        self.minutes = clampedMinutes
        seconds = 0
        totalSeconds = (clampedHours * 3600) + (clampedMinutes * 60)
        configuredTotalSeconds = totalSeconds
    }

    func returnToHome() {
        pause()
        showFinishSession = false
        requestReturnToHome = true
    }

    func start() {
        guard totalSeconds > 0, timer == nil else { return }

        showFinishSession = false
        isRunning = true
        let newTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func reset(hours: Int = 2, minutes: Int = 30) {
        configure(hours: hours, minutes: minutes)
    }

    private func tick() {
        guard totalSeconds > 0 else {
            finish()
            return
        }

        totalSeconds -= 1

        if totalSeconds < 60 {
            finish()
        } else {
            updateDisplay()
        }
    }

    private func updateDisplay() {
        hours = totalSeconds / 3600
        minutes = (totalSeconds % 3600) / 60
        seconds = totalSeconds % 60
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        updateDisplay()
        showFinishSession = true
    }
}