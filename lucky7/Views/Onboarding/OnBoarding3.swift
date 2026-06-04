//
//  OnBoarding3.swift
//  lucky7
//

import SwiftUI

struct OnBoarding3: View {
    @Binding var path: [Int]
    var onComplete: () -> Void = {}

    var body: some View {
        OnboardingScreenTemplate(
            step: 3,
            onContinue: onComplete,
            onBack: goBack,
            onGoPrevious: goBack
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
        OnBoarding3(path: .constant([2, 3]))
    }
}
