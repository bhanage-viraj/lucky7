//
//  BreakUnlockOverlay.swift
//  lucky7
//
//  Created by Andrian on 03/06/26.
//

import SwiftUI

// Instant in-app "Instagram unlocked" notification card, shown the moment a break is
// granted. It holds for a beat, then shrinks up toward the Dynamic Island and fades —
// the user then leaves to the app, where the real Live Activity island takes over
// (quietly, no re-expand). No timer here.
struct BreakUnlockOverlay: View {
    let appName: String
    var onFinished: () -> Void = {}

    @State private var collapsed = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if !collapsed {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                card
                    .frame(
                        width: collapsed ? 140 : geo.size.width - 40,
                        height: collapsed ? 38 : 84
                    )
                    .opacity(collapsed ? 0 : 1)   // fades as it reaches the island
                    .position(
                        x: geo.size.width / 2,
                        y: collapsed ? 24 : 105   // just below the Dynamic Island, like a real banner
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: collapsed)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            // instant on submit → hold a beat → shrink up into the island → clear
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { collapsed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { onFinished() }
        }
    }

    private var card: some View {
        ZStack {
            Image("NotificationBlockedApp")
                .resizable()
                .scaledToFill()

            HStack(spacing: 10) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(appName) unlocked")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .opacity(collapsed ? 0 : 1)   // text drops out first
        }
        .clipShape(RoundedRectangle(cornerRadius: collapsed ? 20 : 26, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}
