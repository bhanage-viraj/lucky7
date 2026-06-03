//
//  BreakActivityAttributes.swift
//  lucky7
//
//  Created by Andrian on 02/06/26.
//

import ActivityKit
import Foundation

// shared between the app (starts the activity) and the widget (draws it).
// has to be the exact same type in both targets or ActivityKit won't match them.
struct BreakActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var endsAt: Date
        var statusText: String
    }

    var appName: String
}
