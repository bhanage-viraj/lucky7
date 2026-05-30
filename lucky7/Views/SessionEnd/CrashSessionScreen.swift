// Views/SessionEnd/CrashSessionScreen.swift
// Placeholder for CrashSessionScreen view

import SwiftUI

struct CrashSessionScreen: View {
    /// Called automatically 3s after appearing (e.g. to return to HomePage).
    var onContinue: () -> Void = {}

    @State private var appeared = false
    @State private var shake = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("CanvasRed")
                    .ignoresSafeArea()

                Image("PatternBackgroundSmall")
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    ZStack {
                        Text("🤕")
                            .font(.system(size: 112))
                            .offset(x: 68, y: -32)
                            .rotationEffect(.degrees(appeared ? 9 : 30))
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 1.4)
                            .animation(.spring(response: 0.5, dampingFraction: 0.4).delay(0.2), value: appeared)

                        Image(.titleEndSession)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -20)
                            .blur(radius: appeared ? 0 : 6)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.05), value: appeared)
                    }
                    // ← shake effect on the whole ZStack
                    .offset(x: shake ? -8 : 0)
                    .animation(
                        .interpolatingSpring(stiffness: 600, damping: 8)
                        .repeatCount(4, autoreverses: true)
                        .delay(0.1),
                        value: shake
                    )

                    Text("Oh no, looks like you got distracted this session. Take a moment, reset, and try again.")
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .frame(width: 240)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: appeared)

                    Color.clear
                        .frame(height: 2)

                    Image(systemName: "car.side.rear.and.collision.and.car.side.front")
                        .font(.system(size: 40))
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.4).delay(0.6), value: appeared)

                    Spacer()

                    Text("Tap to go to the next screen")
                        .font(.system(size: 14))
                        .opacity(appeared ? 0.8 : 0)
                        .animation(.easeIn(duration: 0.5).delay(0.9), value: appeared)
                }
                .foregroundStyle(.white)
            }
            .onAppear {
                appeared = true
                shake = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    onContinue()
                }
            }
        }
    }
}

#Preview {
    CrashSessionScreen()
}
