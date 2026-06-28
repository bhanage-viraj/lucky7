//
//  AppBlockOnboardingScreen.swift
//  lucky7
//
//  Created by Andrian on 29/05/26.
//

import SwiftUI
#if os(iOS)
import FamilyControls
#endif

struct AppBlockOnboardingScreen: View {
    #if os(iOS)
    @EnvironmentObject private var focusController: FocusViewModel
    #endif

    @State private var showPicker = false
    @State private var isRequestingAuth = false
    @State private var authError: String?

    let onDone: () -> Void

    var body: some View {
        ResponsiveReader { metrics in
            ZStack {
                Color("CanvasBlue").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: metrics.isShort ? 18 : 24) {
                        Spacer(minLength: metrics.isShort ? 12 : 44)

                        Image("TicketStopSign")
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: metrics.isShort ? 128 : 180)
                            .accessibilityDecorative()

                        VStack(spacing: 12) {
                            Text("Block your distractions")
                                .font(.custom("SpecialGothicExpandedOne-Regular", size: metrics.isNarrow ? 24 : 28))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.82)

                            Text("Pick the apps that pull you away from focus.\nWe'll block them while Rush Hour is running.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineSpacing(1.5)
                        }

                        Spacer(minLength: metrics.isShort ? 12 : 44)

                        pickerCard

                        continueButton
                    }
                    .adaptiveReadableFrame(metrics, maxWidth: metrics.isPad ? 520 : nil)
                    .frame(minHeight: metrics.height - metrics.safeArea.top - metrics.safeArea.bottom)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, metrics.safeArea.top)
                    .padding(.bottom, max(24, metrics.safeArea.bottom + 16))
                }
            }
        }
        #if os(iOS)
        .familyActivityPicker(isPresented: $showPicker, selection: focusController.selectionBinding)
        #endif
        .alert(
            "Screen Time access needed",
            isPresented: .constant(authError != nil),
            presenting: authError
        ) { _ in
            Button("OK") { authError = nil }
        } message: { error in
            Text(error)
        }
    }

    @ViewBuilder
    private var pickerCard: some View {
        #if os(iOS)
        Button {
            Task { await presentPicker() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: focusController.hasSelection ? "lock.shield.fill" : "lock.shield")
                    .font(.title3)
                    .foregroundStyle(Color("CanvasBlue"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(focusController.hasSelection ? "Apps locked" : "Pick apps to block")
                        .font(.headline)
                        .foregroundStyle(.black)
                    Text(focusController.hasSelection ? focusController.selectionSummary : "Tap to choose")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isRequestingAuth {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isRequestingAuth)
        #endif
    }

    private var continueButton: some View {
        Button {
            #if os(iOS)
            focusController.persistSelection()
            #endif
            onDone()
        } label: {
            Text("CONTINUE")
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 15))
                .tracking(1.2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.vertical, 18)
                .background(.black, in: Capsule())
        }
    }

    #if os(iOS)
    @MainActor
    private func presentPicker() async {
        if !ScreenTimeMonitorService.isAuthorized {
            isRequestingAuth = true
            defer { isRequestingAuth = false }
            do {
                try await ScreenTimeMonitorService.requestAuthorization()
            } catch {
                authError = error.localizedDescription
                return
            }
        }
        showPicker = true
    }
    #endif
}

#if os(iOS)
#Preview {
    AppBlockOnboardingScreen(onDone: {})
        .environmentObject(FocusViewModel())
}
#endif
