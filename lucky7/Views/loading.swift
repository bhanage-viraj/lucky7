//
//  loading.swift
//  lucky7
//

import SwiftUI

struct Loading: View {
    @AppStorage("didShowAppBlockOnboarding") private var didShowOnboarding = false
    @State private var pulse = false
    @State private var showHome = false

    init() {
        // Dark tab bar only — without forcing the whole app into dark mode.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.10, alpha: 1.0)

        let item = UITabBarItemAppearance()
        item.normal.iconColor = UIColor(white: 1.0, alpha: 0.55)
        item.normal.titleTextAttributes = [.foregroundColor: UIColor(white: 1.0, alpha: 0.55)]
        item.selected.iconColor = .white
        item.selected.titleTextAttributes = [.foregroundColor: UIColor.white]

        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {

        if showHome {
            // jailbreak: gate the app behind the app-block onboarding the first launch
            if didShowOnboarding {
                TabView {
                    Tab("Rush Hour", systemImage: "rays") {
                        HomePage()
                    }

                    Tab("Monitor", systemImage: "play.square.stack.fill") {
                        MonitorScreen()
                    }
                }
                .tint(.white)
                .onAppear { UIApplication.shared.enableTapToDismissKeyboard() }
            } else {
//                AppBlockOnboardingScreen(onDone: {
//                    didShowOnboarding = true
//                })
                OnBoarding1(onComplete: {
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

                // Pulse Animation
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

                // Start pulse animation
                pulse = true

                // Tap anywhere outside a text field to dismiss the keyboard.
                DispatchQueue.main.async {
                    UIApplication.shared.enableTapToDismissKeyboard()
                }

                // Navigate after 3 sec
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut) {
                        showHome = true
                    }
                }
            }
        }
    }
}

#Preview {
    Loading()
}
