//
//  loading.swift
//  lucky7
//

import SwiftUI

struct Loading: View {
    @AppStorage("didShowAppBlockOnboarding") private var didShowOnboarding = false

    @State private var pulse = false
    @State private var showNext = false

    var body: some View {
        if showNext {
            if didShowOnboarding {
                MainTabView()
            } else {
                AppBlockOnboardingScreen(onDone: {
                    didShowOnboarding = true
                })
            }
        } else {
            ZStack {
                Color.blue
                    .ignoresSafeArea()

                Image("load6")
                Image("load7")
                Image("load8")

                Image("Rushhourload")
                    .scaleEffect(pulse ? 1.08 : 0.92)
                    .opacity(pulse ? 1 : 0.75)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: pulse
                    )
            }
            .onAppear {
                pulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut) {
                        showNext = true
                    }
                }
            }
        }
    }
}

#Preview {
    Loading()
}
