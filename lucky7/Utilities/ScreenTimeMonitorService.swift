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
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    static func requestAuthorization() async throws {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            throw AuthorizationError.underlying(error)
        }
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            throw AuthorizationError.denied
        }
    }
}
#endif
