import Foundation
import SwiftData

@Model
final class Distraction: Identifiable {
    var id: UUID
    var sessionId: UUID

    var appOpened: String
    var tokenData: Data?
    var appBundleId: String?
    var appDisplayName: String?

    var reason: String
    var reasonSubmitted: Bool

    var startTime: Date
    var endTime: Date?

    var sourceKind: String
    var actionTaken: String?

    var breakGrantedUntil: Date?

    var distractionDuration: TimeInterval {
        startTime.intervalInSeconds(to: endTime ?? Date())
    }

    var isBreakActive: Bool {
        guard let until = breakGrantedUntil else { return false }
        return until > .now
    }

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        appOpened: String = "",
        reason: String = "",
        startTime: Date = .now,
        endTime: Date? = nil,
        tokenData: Data? = nil,
        appBundleId: String? = nil,
        appDisplayName: String? = nil,
        reasonSubmitted: Bool = false,
        sourceKind: String = "userManual",
        actionTaken: String? = nil,
        breakGrantedUntil: Date? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.appOpened = appOpened
        self.reason = reason
        self.startTime = startTime
        self.endTime = endTime
        self.tokenData = tokenData
        self.appBundleId = appBundleId
        self.appDisplayName = appDisplayName
        self.reasonSubmitted = reasonSubmitted
        self.sourceKind = sourceKind
        self.actionTaken = actionTaken
        self.breakGrantedUntil = breakGrantedUntil
    }
}
