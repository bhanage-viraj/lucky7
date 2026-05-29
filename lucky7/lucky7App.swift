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
    private var dummyFrames: [UIImage] {
        ["dummySnapshot1", "dummySnapshot2", "dummySnapshot3"]
            .compactMap { UIImage(named: $0) }
    }

    var body: some Scene {
        WindowGroup {
            SessionDetails(sessionId: UUID(), videoFrames: dummyFrames)
        }
        .modelContainer(for: Session.self)
    }
}
