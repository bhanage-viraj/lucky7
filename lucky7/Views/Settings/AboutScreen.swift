//
//  AboutScreen.swift
//  lucky7
//

import SwiftUI

struct AboutScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color("CanvasBlue").ignoresSafeArea()
            Image("PatternBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                Image("RushHourLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170)

                Text("Version 1.0")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 18)

                Text("Rush Hour is a focus companion that combines timed sessions, timelapse reviews, and app blocking to help you stay focused and build better habits.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
                    .padding(.top, 18)

                Text("Copyright © 2026\nAll rights reserved.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)

                Spacer()
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    AboutScreen()
}
