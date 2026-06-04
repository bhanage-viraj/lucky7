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
            step: 3
        ) {
            mainContent
        }
        .navigationBarBackButtonHidden()
    }
    
    private var mainContent: some View {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Text("Lock Out Your Distractions")
                        .font(.custom("Special Gothic Expanded One", size: 35))
                    Color.clear
                        .frame(height: 16)
                    (
                        Text("Select the apps that distracts. We'll remind you to stay focused when it matters most.")
                            .font(.system(size: 17))
                    )
                    .multilineTextAlignment(.center)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                ZStack{
                    Image(.blockedAppsMainScreen)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                    
                    Image(.blueLock)
                        .offset(x: 124, y: 128)
                    
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
}

#Preview {
    NavigationStack {
        OnBoarding3(path: .constant([]))
    }
}
