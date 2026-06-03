//
//  lucky7App.swift
//  lucky7
//
//  Created by Viraj Bhanage on 20/05/26.
//

import SwiftUI
import SwiftData

@main
struct lucky7App: App {
    @StateObject private var sessionTimer = SessionTimerViewModel()
    @StateObject private var sessionRecording = SessionRecordingViewModel()

    var body: some Scene {
        WindowGroup {
            Loading()
                .environmentObject(sessionTimer)
                .environmentObject(sessionRecording)
        }
        .modelContainer(for: [Session.self, Distraction.self])
    }
}
