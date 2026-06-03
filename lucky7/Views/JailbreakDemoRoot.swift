//
//  JailbreakDemoRoot.swift
//  lucky7
//
//  Created by Andrian on 29/05/26.
//

import SwiftUI

#if os(iOS)
struct JailbreakDemoRoot: View {
    @StateObject private var focusController = FocusViewModel()
    @State private var path: [Route] = []

    enum Route: Hashable {
        case setup
        case session(duration: TimeInterval, id: UUID)
    }

    var body: some View {
        NavigationStack(path: $path) {
            home
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .setup:
                        SetupScreen { duration in
                            let sessionId = UUID()
                            path.append(.session(duration: duration, id: sessionId))
                        }
                    case .session(let duration, let id):
                        ActiveFocusScreen(
                            plannedDuration: duration,
                            sessionId: id,
                            onEnd: { path.removeAll() }
                        )
                    }
                }
        }
        .environmentObject(focusController)
    }

    private var home: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("lucky7")
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 48))
                .foregroundStyle(Color("CanvasBlue"))
            Text("Focus session prototype")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                path.append(.setup)
            } label: {
                Text("Start a session")
                    .font(.custom("SpecialGothicExpandedOne-Regular", size: 16))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(.black, in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    JailbreakDemoRoot()
}
#endif
