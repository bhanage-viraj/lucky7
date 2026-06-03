//
//  ActiveFocusScreen.swift
//  lucky7
//
//  Created by Andrian on 29/05/26.
//

import SwiftUI
import SwiftData

struct ActiveFocusScreen: View {
    let plannedDuration: TimeInterval
    let sessionId: UUID
    let onEnd: () -> Void

    @State private var startedAt: Date = .now
    @State private var now: Date = .now
    @State private var timer: Timer?

    #if os(iOS)
    @EnvironmentObject private var focusController: FocusViewModel
    #endif

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var pendingPrompt: PendingPrompt?

    struct PendingPrompt: Identifiable {
        let id = UUID()
        let distraction: Distraction
        let tokenDataToClear: Data?
    }

    var elapsed: TimeInterval {
        now.timeIntervalSince(startedAt)
    }

    var remaining: TimeInterval {
        max(0, plannedDuration - elapsed)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                statusBadge
                Spacer()
                countdown
                Spacer()
                activeBreaksList
                Spacer()
                actionButtons
            }
            .padding(20)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startTicking()
            checkPendingEvents()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { checkPendingEvents() }
        }
        .onDisappear { stopTicking() }
        .fullScreenCover(item: $pendingPrompt) { prompt in
            DistractionPromptScreen(
                appName: prompt.distraction.appOpened.isEmpty ? "this app" : prompt.distraction.appOpened,
                countToday: 1,
                onBackToSession: {
                    modelContext.delete(prompt.distraction)
                    try? modelContext.save()
                    pendingPrompt = nil
                },
                onBreakWithReason: { reason in
                    prompt.distraction.reason = reason
                    prompt.distraction.reasonSubmitted = true
                    prompt.distraction.endTime = .now
                    #if os(iOS)
                    focusController.grantBreak(for: prompt.distraction)
                    #endif
                    try? modelContext.save()
                    pendingPrompt = nil
                }
            )
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        #if os(iOS)
        if focusController.isEngaged {
            Label("LOCKED", systemImage: "lock.fill")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color("CanvasBlue"), in: .capsule)
        }
        #endif
    }

    private var countdown: some View {
        VStack(spacing: 8) {
            Text(timeString(remaining))
                .font(.system(size: 84, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var activeBreaksList: some View {
        #if os(iOS)
        if !focusController.activeBreaks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Active breaks")
                    .font(.headline)
                ForEach(focusController.activeBreaks) { d in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.appDisplayName ?? (d.appOpened.isEmpty ? "App" : d.appOpened))
                                .font(.headline)
                            Text(timeString(focusController.remainingSeconds(for: d)) + " left")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Stop early") {
                            focusController.endBreakEarly(for: d)
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black, in: .capsule)
                        .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
                }
            }
        }
        #endif
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: endSession) {
                Text("End session")
                    .font(.custom("SpecialGothicExpandedOne-Regular", size: 16))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(red: 0.902, green: 0.224, blue: 0.275), in: Capsule())
            }
        }
    }

    private func checkPendingEvents() {
        guard pendingPrompt == nil else { return }
        guard let pair = SharedJailbreakStore.nextUnhandledBreak() else { return }

        let displayName = pair.config?.displayName ?? pair.action.displayName ?? ""
        let bundleId = pair.config?.bundleId ?? pair.action.bundleId
        let tokenData = pair.action.tokenData ?? pair.config?.tokenData

        let distraction = Distraction(
            sessionId: sessionId,
            appOpened: displayName,
            startTime: pair.config?.occurredAt ?? pair.action.occurredAt,
            tokenData: tokenData,
            appBundleId: bundleId,
            appDisplayName: displayName.isEmpty ? nil : displayName,
            sourceKind: "shieldAction",
            actionTaken: "break"
        )
        modelContext.insert(distraction)
        try? modelContext.save()

        pendingPrompt = PendingPrompt(distraction: distraction, tokenDataToClear: tokenData)
    }

    private func endSession() {
        #if os(iOS)
        focusController.release()
        #endif
        SharedJailbreakStore.removeAll()
        onEnd()
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in now = .now }
        }
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

#if os(iOS)
#Preview {
    ActiveFocusScreen(
        plannedDuration: 25 * 60,
        sessionId: UUID(),
        onEnd: {}
    )
    .environmentObject(FocusViewModel())
    .modelContainer(for: [Session.self, Distraction.self], inMemory: true)
}
#endif
