//
//  BreakUnlockOverlay.swift
//  lucky7
//
//  Created by Andrian on 03/06/26.
//

import SwiftUI

// Instant in-app "Instagram unlocked" notification banner, shown the moment a break is
// granted. It gently fades + scales in (no abrupt full-size pop), holds for a beat, then
// shrinks up toward the Dynamic Island and fades.
//
// To visualize/resize it: open this file in Xcode and show the Canvas (⌥⌘↩). The
// #Preview renders the banner over a grey stand-in. Tweak the constants below; the
// canvas updates live.
struct BreakUnlockOverlay: View {
    let appName: String
    var onFinished: () -> Void = {}
    /// Previews pass `false` so the banner stays expanded (easy to size in the canvas).
    var autoCollapse: Bool = true

    // ── tweak these to resize the banner ───────────────────────────────
    private let sideInset: CGFloat = 90    // bigger number = NARROWER card (screen width − this)
    private let bannerHeight: CGFloat = 64  // card height in points
    private let bannerY: CGFloat = 96       // vertical centre (distance from the top)
    private let textSize: CGFloat = 16      // "App unlocked" font size
    // ───────────────────────────────────────────────────────────────────

    @State private var shown = false       // entrance: fade + gentle scale-in
    @State private var collapsed = false   // exit: shrink up into the island

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                card
                    .frame(
                        width: collapsed ? 130 : geo.size.width - sideInset,
                        height: collapsed ? 36 : bannerHeight
                    )
                    .scaleEffect(shown ? 1 : 0.85)             // grow-in, not an abrupt full-size pop
                    .opacity(collapsed ? 0 : (shown ? 1 : 0))
                    .position(
                        x: geo.size.width / 2,
                        y: collapsed ? 24 : bannerY
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: shown)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: collapsed)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            shown = true                                       // fade + scale in
            guard autoCollapse else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { collapsed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) { onFinished() }
        }
    }

    private var card: some View {
        ZStack {
            Image("NotificationBlockedApp")
                .resizable()
                .scaledToFill()

            HStack(spacing: 10) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: textSize, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(appName) unlocked")
                    .font(.system(size: textSize, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .opacity(collapsed ? 0 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: collapsed ? 18 : 22, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()   // stand-in for the camera/recording screen
        BreakUnlockOverlay(appName: "Instagram", autoCollapse: false)
    }
}
