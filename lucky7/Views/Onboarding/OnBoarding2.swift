//
//  OnBoarding2.swift
//  lucky7
//

import SwiftUI

struct OnBoarding2: View {
    @Binding var path: [Int]

    var body: some View {
        OnboardingScreenTemplate(step: 2, onContinue: {
            path.append(3)
        })
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    NavigationStack {
        OnBoarding2(path: .constant([]))
    }
}
