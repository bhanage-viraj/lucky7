//
//  ScreenTimeMonitorService.swift
//  lucky7ta
//
//  Created by Andrian on 29/05/26.
//

import Foundation
#if os(iOS)
import FamilyControls

@MainActor
enum ScreenTimeMonitorService {
    enum AuthorizationError: Error, LocalizedError {
        case denied
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .denied:
                return "Screen Time access was denied. Enable Family Controls for lucky7 in Settings → Screen Time."
            case .underlying(let error):
                return error.localizedDescription
            }
        }
    }

    static var isAuthorized: Bool {
        let status = AuthorizationCenter.shared.authorizationStatus
        return status == .approved || status == .approvedWithDataAccess
    }

    // true when the user granted the stronger data-access level (lets us read
    // installedApplications → recover bundle ids). Needs the app-and-website-usage
    // entitlement + an eligible region (EU / DMA).
    static var hasDataAccess: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approvedWithDataAccess
    }

    static func requestAuthorization() async throws {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            throw AuthorizationError.underlying(error)
        }
        guard isAuthorized else {
            throw AuthorizationError.denied
        }
    }
}
#endif
