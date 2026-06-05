//
//  OnBoarding1.swift
//  lucky7
//
//  Created by Viraj Bhanage on 04/06/26.
//

import SwiftUI

struct OnBoarding1: View {
    var onComplete: () -> Void = {}

    @State private var path: [Int] = []

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingScreenTemplate(step: 1) {
                path.append(2)
            }
            .navigationDestination(for: Int.self) { step in
                switch step {
                case 2:
                    OnBoarding2(path: $path)
                case 3:
                    OnBoarding3(path: $path, onComplete: onComplete)
                default:
                    EmptyView()
                }
            }
        }
    }
}

#Preview {
    OnBoarding1()
}
