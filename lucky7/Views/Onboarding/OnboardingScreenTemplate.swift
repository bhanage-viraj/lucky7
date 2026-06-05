//
//  OnboardingScreenTemplate.swift
//  lucky7
//

import SwiftUI

struct OnboardingScreenTemplate: View {
    let step: Int
    var onContinue: () -> Void = {}

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("CanvasBlue")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                    Image("PatternBackground")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .offset(y: 400)
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    progressIndicator
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    Spacer(minLength: 20)

                    Image("OnboardingContainer")
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 20)

                    Spacer(minLength: 20)

                    Button(action: onContinue) {
                        Text("CONTINUE")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Capsule().fill(Color.black))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index == step ? 1 : 0.35))
                    .frame(height: 5)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview("Flow") {
    OnBoarding1()
}

#Preview("Step 1") {
    OnboardingScreenTemplate(step: 1)
}

#Preview("Step 2") {
    OnboardingScreenTemplate(step: 2)
}

#Preview("Step 3") {
    OnboardingScreenTemplate(step: 3)
}
