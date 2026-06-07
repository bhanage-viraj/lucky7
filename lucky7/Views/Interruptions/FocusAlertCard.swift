//
//  FocusAlertCard.swift
//  lucky7
//

import SwiftUI

// Centered white "card" alert for the break flow, styled after the figma:
//   • App Unlocked        — confirms the break, then shrinks UP into the Dynamic Island
//                           (the Live Activity is already live up there, so it reads as a hand-off)
//   • One break at a time — warning shown when a break is already running
//
// 354-wide white card, 2px black border, 24 corner radius, black GOT IT pill, over a dimmed backdrop.
struct FocusAlertCard: View {
    let title: String
    let message: String
    var buttonTitle: String = "GOT IT"
    /// App Unlocked flies up + shrinks into the Dynamic Island on dismiss; everything else just fades.
    var shrinkToIsland: Bool = false
    /// Auto-dismiss after a beat (App Unlocked does this so it doesn't sit on top of the session).
    var autoDismiss: Bool = false
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var leaving = false

    var body: some View {
        GeometryReader { geo in
            // fly the card up to roughly the Dynamic Island's center (physical top + ~30pt).
            // adding safeAreaInsets.top puts us in screen space; a .center anchor keeps the
            // shrink symmetric and independent of the card's height.
            let islandCenter: CGFloat = 30
            let shrinkOffset = -(geo.size.height / 2 + geo.safeAreaInsets.top - islandCenter)

            ZStack {
                // dim the paused recording behind the card (stays modal through the leaving phase)
                Color.black.opacity(appeared && !leaving ? 0.4 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())

                card
                    .scaleEffect(leaving && shrinkToIsland ? 0.08 : (appeared ? 1 : 0.9), anchor: .center)
                    .offset(y: leaving && shrinkToIsland ? shrinkOffset : 0)
                    .opacity(appeared && !leaving ? 1 : 0)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: appeared)
        }
        .onAppear {
            appeared = true
            guard autoDismiss else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { dismiss() }
        }
    }

    private func dismiss() {
        guard !leaving else { return }
        if shrinkToIsland {
            // collapse up toward the island, then hand off to the Live Activity
            withAnimation(.easeIn(duration: 0.45)) { leaving = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onDismiss() }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { leaving = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
        }
    }

    private var card: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(.black.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button { dismiss() } label: {
                Text(buttonTitle)
                    .font(.custom("SpecialGothicExpandedOne-Regular", size: 14))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(.black))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(width: 354)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.black, lineWidth: 2))
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        FocusAlertCard(
            title: "One break at a time",
            message: "An app is already unlocked. You can unlock another app after returning to your focus session.",
            onDismiss: {}
        )
    }
}
