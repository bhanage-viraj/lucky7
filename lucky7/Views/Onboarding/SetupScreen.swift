//
//  SetupScreen.swift
//  lucky7
//
//  Created by Andrian on 29/05/26.
//

import SwiftUI
#if os(iOS)
import FamilyControls
#endif

struct SetupScreen: View {
    @StateObject private var viewModel = SetupViewModel()
    #if os(iOS)
    @EnvironmentObject private var focusController: FocusViewModel
    #endif

    @State private var showPicker = false
    @State private var isRequestingAuth = false
    @State private var authError: String?

    let onStart: (TimeInterval) -> Void

    var body: some View {
        ResponsiveReader { metrics in
            ScrollView(showsIndicators: false) {
                VStack(spacing: metrics.isShort ? 18 : 24) {
                    header
                    presetSection
                    customSection
                    lockSection
                    startButton
                }
                .adaptiveReadableFrame(metrics, maxWidth: metrics.isPad ? 620 : nil, alignment: .center)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.top, metrics.verticalPadding + metrics.safeArea.top)
                .padding(.bottom, 32 + metrics.safeArea.bottom)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
        }
        #if os(iOS)
        .familyActivityPicker(isPresented: $showPicker, selection: $focusController.selection)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start a session")
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 32))
            Text("Pick a duration and the apps to lock.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var presetSection: some View {
        VStack(spacing: 12) {
            ForEach(SetupViewModel.presets) { preset in
                Button {
                    viewModel.selectPreset(preset)
                } label: {
                    presetRow(preset: preset, isSelected: !viewModel.useCustom && viewModel.selectedPreset == preset)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func presetRow(preset: SetupViewModel.Preset, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.label).font(.headline)
                Text(preset.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(preset.minutes) min")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color("CanvasBlue") : Color.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color("CanvasBlue").opacity(0.1) : Color(.secondarySystemBackground))
        )
    }

    private var customSection: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.selectCustom()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom").font(.headline)
                        Text("Pick your own number").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: viewModel.useCustom ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(viewModel.useCustom ? Color("CanvasBlue") : Color.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(viewModel.useCustom ? Color("CanvasBlue").opacity(0.1) : Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)

            if viewModel.useCustom {
                Stepper(
                    "Duration: \(viewModel.customMinutes) min",
                    value: $viewModel.customMinutes,
                    in: 1...180
                )
                .padding(16)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
            }
        }
    }

    private var lockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apps to lock during the session")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            #if os(iOS)
            Button {
                Task { await presentPicker() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: focusController.hasSelection ? "lock.shield.fill" : "lock.shield")
                        .font(.title3)
                        .foregroundStyle(focusController.hasSelection ? Color("CanvasBlue") : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(focusController.hasSelection ? "Apps locked" : "Pick apps to block")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(focusController.hasSelection ? focusController.selectionSummary : "Choose distractions to block while you focus")
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
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            .disabled(isRequestingAuth)
            #endif
        }
    }

    private var startButton: some View {
        Button {
            #if os(iOS)
            focusController.engage()
            #endif
            onStart(viewModel.plannedDuration)
        } label: {
            Text("Start session")
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 16))
                .tracking(1.2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.vertical, 18)
                .background(.black, in: Capsule())
        }
        .padding(.top, 8)
    }

    #if os(iOS)
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
    SetupScreen(onStart: { _ in })
        .environmentObject(FocusViewModel())
}
#endif
