//
//  OnboardingScreenTemplate.swift
//  lucky7
//

import SwiftUI

struct OnboardingScreenTemplate: View {
    let step: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("CanvasBlue")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                    Image("frame219")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height * 0.55)
                        .clipped()
                        
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    progressIndicator
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    Spacer(minLength: 20)

                    Image("frame218")
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 20)
                        

                    Spacer(minLength: 20)
                    

                    Text("Tap to continue")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        
                    
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

#Preview("Step 1") {
    OnboardingScreenTemplate(step: 1)
}

#Preview("Step 2") {
    OnboardingScreenTemplate(step: 2)
}

#Preview("Step 3") {
    OnboardingScreenTemplate(step: 3)
}
