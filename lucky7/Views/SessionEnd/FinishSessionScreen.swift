// Views/SessionEnd/FinishSessionScreen.swift
// Placeholder for FinishSessionScreen view

import SwiftUI

struct FinishSessionScreen: View {
    @State private var appeared = false
    
    var body: some View {
        NavigationStack{
            ZStack {
                Color("CanvasBlue")
                    .ignoresSafeArea()
                
                Image("PatternBackgroundSmall")
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    ZStack {
                        Text("🤩")
                            .font(.system(size: 40))
                            .offset(y: -60)
                            .rotationEffect(.degrees(-6))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: appeared)
                        
                        Image(.titleFinishSession)
                            .scaleEffect(appeared ? 1 : 0.7)
                            .opacity(appeared ? 1 : 0)
                            .blur(radius: appeared ? 0 : 8)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1), value: appeared)
                    }
                    
                    Text("You stayed on track and got things done. Reflect on your session and see your focus stats.")
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .frame(width: 240)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: appeared)
                    
                    Color.clear
                        .frame(height: 2)
                    
                    Image(systemName: "flag.pattern.checkered.2.crossed")
                        .font(.system(size: 40))
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .animation(.spring(response: 0.7, dampingFraction: 0.5).delay(0.55), value: appeared)
                    
                    Spacer()
                    
                    Text("Tap to go to the next screen")
                        .font(.system(size: 14))
                        .opacity(appeared ? 0.8 : 0)
                        .animation(.easeIn(duration: 0.5).delay(0.8), value: appeared)
                }
                .foregroundStyle(.white)
            }
            .onAppear {
                appeared = true
            }
        }
    }
}

#Preview {
    FinishSessionScreen()
}
