//
//  AboutScreen.swift
//  lucky7
//

import SwiftUI

struct AboutScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ResponsiveReader { metrics in
            ZStack {
                AdaptivePatternBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        HStack {
                            AdaptiveIconButton(systemName: "chevron.left", action: { dismiss() })
                                .accessibilityLabel("Back")
                            Spacer()
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, max(8, metrics.safeArea.top + 2))

                        Spacer(minLength: metrics.isShort ? 28 : 90)

                        Image("RushHourLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: metrics.isPad ? 210 : 170)
                            .accessibilityDecorative()

                        Text("Version 1.0")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 18)

                        Text("Rush Hour is a focus companion that combines timed sessions, timelapse reviews, and app blocking to help you stay focused and build better habits.")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, metrics.isPad ? 0 : 36)
                            .padding(.top, 18)

                        Text("Copyright © 2026\nAll rights reserved.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.top, 22)

                        Spacer(minLength: metrics.isShort ? 32 : 140)
                    }
                    .adaptiveReadableFrame(metrics, maxWidth: metrics.isPad ? 560 : nil)
                    .frame(minHeight: metrics.height)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    AboutScreen()
}
