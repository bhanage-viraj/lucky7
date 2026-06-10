//
//  loading.swift
//  lucky7
//

import SwiftUI
import Combine

struct Loading: View {
    @AppStorage("didShowAppBlockOnboarding") private var didShowOnboarding = false
    @State private var pulse = false
    @State private var showHome = false
    @State private var selectedTab = 0
    @StateObject private var tabBarVisibility = TabBarVisibility()

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
                ZStack(alignment: .bottom) {
                    // Both screens stay alive so each keeps its own navigation
                    // stack and scroll state; only the selected one is shown.
                    HomePage(isActiveTab: selectedTab == 0)
                        .opacity(selectedTab == 0 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 0)
                        .zIndex(selectedTab == 0 ? 1 : 0)

                    MonitorScreen()
                        .opacity(selectedTab == 1 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 1)
                        .zIndex(selectedTab == 1 ? 1 : 0)

                    if !tabBarVisibility.isHidden {
                        FloatingTabBar(selection: $selectedTab)
                            .padding(.bottom, 4)
                            .zIndex(2)
                            .transition(.opacity)
                    }
                }
                .environment(\.tabBarVisibility, tabBarVisibility)
                .onAppear { UIApplication.shared.enableTapToDismissKeyboard() }
                .onReceive(NotificationCenter.default.publisher(for: .returnToHomeTab)) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 0 }
                }
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
                    .accessibilityDecorative()

                Image("load7")
                    .accessibilityDecorative()

                Image("load8")
                    .accessibilityDecorative()

                // Pulse Animation
                Image("Rushhourload")
                    .scaleEffect(pulse ? 1.08 : 0.92)
                    .opacity(pulse ? 1 : 0.75)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: pulse
                    )
                    .accessibilityDecorative()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rush Hour")
            .accessibilityValue("Loading")
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

// MARK: - Floating tab bar

/// Custom pill-shaped tab bar that floats above the content. The selected tab is a
/// filled black circle; unselected tabs show a bare icon. Icons are placeholders —
/// swap them as needed.
struct FloatingTabBar: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 10) {
            tabButton(index: 0, systemImage: "timer")
            tabButton(index: 1, systemImage: "calendar.badge.clock")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
        )
        .overlay(
            Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }

    private func tabButton(index: Int, systemImage: String) -> some View {
        let titles = ["Home", "Sessions"]
        let isSelected = selection == index
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selection = index }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(isSelected ? .white : .black)
                .frame(width: 76, height: 48)
                .background(
                    Capsule().fill(isSelected ? Color.black : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(titles[index])
        .accessibilityHint(isSelected ? "Selected tab" : "Switch to \(titles[index]) tab")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityInputLabels([titles[index].lowercased(), index == 0 ? "home" : "sessions", "tab"])
    }
}

// MARK: - Floating tab bar visibility

/// Tracks how many on-screen views want the floating tab bar hidden. A counter
/// (not a Bool) keeps push/pop transitions flicker-free when a new screen
/// appears before the previous one disappears.
final class TabBarVisibility: ObservableObject {
    @Published private var hideCount = 0
    var isHidden: Bool { hideCount > 0 }
    func push() { hideCount += 1 }
    func pop() { hideCount = max(0, hideCount - 1) }
}

private struct TabBarVisibilityKey: EnvironmentKey {
    static let defaultValue = TabBarVisibility()
}

extension EnvironmentValues {
    var tabBarVisibility: TabBarVisibility {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }
}

extension View {
    /// Hides the floating tab bar while this view is on screen. Apply to pushed
    /// detail screens so the bar only shows on Home / Monitor (and Search).
    func hidesFloatingTabBar() -> some View {
        modifier(HidesFloatingTabBar())
    }
}

private struct HidesFloatingTabBar: ViewModifier {
    @Environment(\.tabBarVisibility) private var visibility
    func body(content: Content) -> some View {
        content
            .onAppear { withAnimation(.easeInOut(duration: 0.2)) { visibility.push() } }
            .onDisappear { withAnimation(.easeInOut(duration: 0.2)) { visibility.pop() } }
    }
}

#Preview {
    Loading()
}
