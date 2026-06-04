//
//  OnBoarding3.swift
//  lucky7
//

import SwiftUI

struct OnBoarding3: View {
    @Binding var path: [Int]
    var onComplete: () -> Void = {}

    var body: some View {
        OnboardingScreenTemplate(step: 3, onContinue: {
            onComplete()
        })
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    NavigationStack {
        OnBoarding3(path: .constant([]))
    }
}
