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
    var body: some Scene {
        WindowGroup {
            JailbreakDemoRoot()
                .task {
                    await NotificationPermission.requestIfNeeded()
                }
        }
        .modelContainer(for: [Session.self, Distraction.self])
    }
}
