//
//  BreakRecordsView.swift
//  lucky7
//
//  Created by Andrian on 02/06/26.
//

import SwiftUI
import SwiftData
import FamilyControls
import ManagedSettings
import Vision
import UserNotifications
import UIKit

// every distraction grouped by the session it happened in. each row renders the
// blocked app with Apple's own Label(token) — that's the only way to show the
// real name + icon, since iOS never gives the app the name as plain text.
struct BreakRecordsView: View {
    @Query(sort: \Distraction.startTime, order: .reverse) private var distractions: [Distraction]
    @EnvironmentObject private var focusController: FocusViewModel
    @State private var redirectResult = "(tap to test)"
    @State private var configTick = 0
    @State private var lastApp = "nil"
    @State private var lastBundle = "nil"
    @State private var ocrResult = "(tap Run OCR)"
    @State private var iosVersion = ""
    @State private var directOpen = ""
    @State private var notifStatus = "…"
    @State private var dataAuth = "…"
    @State private var hasDataAccess = false
    @State private var installedInfo = "…"

    // distractions bucketed per session, newest session first
    private var sessionGroups: [(id: UUID, items: [Distraction])] {
        let grouped = Dictionary(grouping: distractions) { $0.sessionId }
        var result: [(id: UUID, items: [Distraction])] = []
        for (sessionId, items) in grouped {
            let sorted = items.sorted { $0.startTime > $1.startTime }
            result.append((id: sessionId, items: sorted))
        }
        result.sort { ($0.items.first?.startTime ?? .distantPast) > ($1.items.first?.startTime ?? .distantPast) }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Routing — why Break/Back open (or don't)") {
                    HStack { Text("iOS version"); Spacer(); Text(iosVersion).foregroundStyle(.secondary) }
                    HStack { Text("direct-open (26.5)"); Spacer(); Text(directOpen).foregroundStyle(.secondary) }
                    HStack { Text("notifications"); Spacer(); Text(notifStatus).foregroundStyle(notifStatus == "ON" ? .green : .orange) }
                }
                Section("Data access — can we recover the bundle id?") {
                    HStack { Text("authorization"); Spacer(); Text(dataAuth).foregroundStyle(hasDataAccess ? .green : .orange) }
                    HStack { Text("installed apps"); Spacer(); Text(installedInfo).foregroundStyle(.secondary) }
                    Button("Request data access") {
                        Task {
                            try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                            refresh()
                        }
                    }
                    HStack { Text("redirect test"); Spacer(); Text(redirectResult).font(.caption2).foregroundStyle(.secondary) }
                    Button("Test redirect to latest break's app") {
                        guard let latest = distractions.first else {
                            redirectResult = "(no break to test)"
                            return
                        }
                        redirectResult = "resolving…"
                        Task { redirectResult = await focusController.redirectDiagnostic(for: latest) }
                    }
                    .disabled(distractions.isEmpty)
                }
                Section("Diagnostics — does the shield reach the app?") {
                    HStack { Text("config→app tick"); Spacer(); Text("\(configTick)").bold() }
                    HStack { Text("last shielded app"); Spacer(); Text(lastApp).foregroundStyle(.secondary) }
                    HStack { Text("last bundle id"); Spacer(); Text(lastBundle).font(.caption2).foregroundStyle(.secondary) }
                }
                Section("OCR experiment — read the label's pixels?") {
                    HStack { Text("OCR'd name"); Spacer(); Text(ocrResult).foregroundStyle(.secondary) }
                    Button("Run OCR on latest break's label") { runOCRTest() }
                }
                if distractions.isEmpty {
                    Section("Distraction records") {
                        Text("No distractions recorded yet.").foregroundStyle(.secondary)
                    }
                }
                ForEach(sessionGroups, id: \.id) { group in
                    Section("Session \(group.id.uuidString.prefix(8)) — \(group.items.count) distraction\(group.items.count == 1 ? "" : "s")") {
                        ForEach(group.items) { DistractionRow(distraction: $0) }
                    }
                }
            }
            .navigationTitle("Distractions")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { refresh() }
            .refreshable { refresh() }
        }
    }

    private func refresh() {
        configTick = SharedJailbreakStore.configTick()
        lastApp = SharedJailbreakStore.lastShieldedAppName() ?? "nil"
        lastBundle = SharedJailbreakStore.lastShieldedBundleId() ?? "nil"

        iosVersion = UIDevice.current.systemVersion
        // the 26.5 API works but is flaky — notification is the fallback
        if #available(iOS 26.5, *) { directOpen = "available (flaky)" } else { directOpen = "n/a — notification only" }
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let status: String
            switch s.authorizationStatus {
            case .authorized, .provisional, .ephemeral: status = "ON"
            case .denied: status = "OFF (denied)"
            case .notDetermined: status = "not asked yet"
            @unknown default: status = "?"
            }
            DispatchQueue.main.async { notifStatus = status }
        }

        let fcStatus = AuthorizationCenter.shared.authorizationStatus
        dataAuth = "\(fcStatus)"
        hasDataAccess = (fcStatus == .approvedWithDataAccess)
        Task {
            if let apps = try? await FamilyActivityData.shared.installedApplications {
                await MainActor.run { installedInfo = "\(apps.count) readable ✅" }
            } else {
                await MainActor.run { installedInfo = "no data access ❌" }
            }
        }
    }

    // experiment: render Label(token) offscreen, OCR the pixels to recover the
    // app name as text. if Apple's privacy view renders blank offscreen, this
    // comes back empty (which is the likely outcome).
    @MainActor
    private func runOCRTest() {
        guard let token = distractions.lazy.compactMap(\.tokenData).first.flatMap({
            try? JSONDecoder().decode(ApplicationToken.self, from: $0)
        }) else {
            ocrResult = "(no token to test)"
            return
        }

        let view = Label(token)
            .labelStyle(.titleOnly)
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(.black)
            .padding(24)
            .frame(width: 360, height: 100)
            .background(Color.white)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let cg = renderer.uiImage?.cgImage else {
            ocrResult = "(label rendered blank)"
            return
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try? VNImageRequestHandler(cgImage: cg).perform([request])
        let texts = (request.results as? [VNRecognizedTextObservation] ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
        ocrResult = texts.isEmpty ? "(blank — Apple blocked it)" : texts.joined(separator: " · ")
    }
}

private struct DistractionRow: View {
    let distraction: Distraction

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            appHeader
            Text("Reason: \(distraction.reason.isEmpty ? "—" : distraction.reason)")
                .font(.subheadline)
            Text("Start  \(timeText(distraction.startTime))").font(.caption)
            if let end = distraction.endTime {
                Text("End    \(timeText(end))  ·  \(durationText)").font(.caption)
            } else {
                Text("still open…").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    // Apple renders the real app icon + name from the token; fall back to text
    // only if we somehow don't have a decodable token.
    @ViewBuilder
    private var appHeader: some View {
        if let token = appToken {
            Label(token)
                .labelStyle(.titleAndIcon)
                .font(.headline)
        } else {
            Text(textLabel).font(.headline)
        }
    }

    private var appToken: ApplicationToken? {
        guard let data = distraction.tokenData else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }

    private var textLabel: String {
        if let name = distraction.appDisplayName, !name.isEmpty { return name }
        return distraction.appOpened.isEmpty ? "Unknown app" : distraction.appOpened
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    private var durationText: String {
        let s = Int(distraction.distractionDuration)
        return s >= 60 ? "\(s / 60)m \(s % 60)s" : "\(s)s"
    }
}
