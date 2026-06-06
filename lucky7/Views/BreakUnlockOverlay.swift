//
//  BreakUnlockOverlay.swift
//  lucky7
//

import SwiftUI
import FamilyControls
import ManagedSettings

// In-app status banner styled after the "notification" design reference:
// a colored rounded card with a time, the Rush Hour logo, and a status line.
//   .focus       -> blue card, "In Rush Hours"  (shown when a session starts)
//   .breakUnlock -> red card,  "<App> unlocked" (shown when a break is granted)
//
// The blocked-app NAME comes from the ApplicationToken via Label(token): iOS
// renders the real name without the `app-and-website-usage` data-access
// entitlement, so it works on a plain TestFlight build. (`localizedDisplayName`
// is nil without that entitlement — this Label is the privacy-safe path.)
//
// It drops in from the top, holds for a beat, then slides back up and fades.
// To visualize/resize it: open in Xcode and show the Canvas (⌥⌘↩).
struct BreakUnlockOverlay: View {
    enum Kind { case focus, breakUnlock }

    let kind: Kind
    var appName: String = ""
    var tokenData: Data? = nil
    var timeText: String = ""
    var onFinished: () -> Void = {}
    /// Previews pass `false` so the card stays put (easy to size in the canvas).
    var autoDismiss: Bool = true

    @State private var shown = false

    // ── tweak the banner size here (design original: 373 × 160) ────
    private let cardWidth: CGFloat = 373     // card width in points
    private let cardHeight: CGFloat = 160    // card height in points
    // ───────────────────────────────────────────────────────────────

    private var cardColor: Color {
        switch kind {
        case .focus:       return Color(red: 24.0/255.0,  green: 128.0/255.0, blue: 229.0/255.0) // #1880E5
        case .breakUnlock: return Color(red: 224.0/255.0, green: 45.0/255.0,  blue: 56.0/255.0)  // #E02D38
        }
    }

    // Blocked-app token (encoded with JSONEncoder when the break was recorded).
    private var appToken: ApplicationToken? {
        guard let tokenData else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: tokenData)
    }

    var body: some View {
        VStack {
            card
                .offset(y: shown ? 0 : -220)
                .opacity(shown ? 1 : 0)
            Spacer()
        }
        .padding(.top, 60)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: shown)
        .onAppear {
            shown = true
            guard autoDismiss else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { shown = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { onFinished() }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(timeText)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Image("RushHourLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 52)
            }
            Spacer(minLength: 12)
            statusView
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(20)
        .frame(width: cardWidth, height: cardHeight, alignment: .leading)   // exact design size
        .background(
            ZStack {
                cardColor
                Image("Vector16")           // soft road-curve watermark
                    .resizable()
                    .scaledToFill()
                    .opacity(0.6)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
    }

    @ViewBuilder
    private var statusView: some View {
        switch kind {
        case .focus:
            Text("In Rush Hours")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        case .breakUnlock:
            if let token = appToken {
                HStack(spacing: 6) {
                    Label(token)
                        .labelStyle(.titleOnly)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("unlocked")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            } else {
                Text(appName.isEmpty ? "Unlocked" : "\(appName) unlocked")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        VStack(spacing: 0) {
            BreakUnlockOverlay(kind: .focus, timeText: "2:00", autoDismiss: false)
                .frame(height: 220)
            BreakUnlockOverlay(kind: .breakUnlock, appName: "Instagram", timeText: "15:00", autoDismiss: false)
                .frame(height: 220)
        }
    }
}
