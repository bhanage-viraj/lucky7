//
//  OnBoarding2.swift
//  lucky7
//

import SwiftUI

struct OnBoarding2: View {
    @Binding var path: [Int]

    var body: some View {
        OnboardingScreenTemplate(
            step: 2,
            onContinue: { path.append(3) },
            onBack: goBack,
            onGoPrevious: goBack,
            onGoNext: { path.append(3) }
        )
        .navigationBarBackButtonHidden()
    }

    private func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

#Preview {
    NavigationStack {
        OnBoarding2(path: .constant([2]))
    }
}
