//
//  loading.swift
//  lucky7
//

import SwiftUI

struct Loading: View {
    
    @State private var pulse = false
    @State private var showHome = false
    
    var body: some View {
        
        if showHome {
            HomePage()
        } else {
            
            ZStack {
                
                Color.blue
                    .ignoresSafeArea()
                
                Image("load6")
                
                Image("load7")
                
                Image("load8")
                
                // Pulse Animation
                Image("Rushhourload")
                    .scaleEffect(pulse ? 1.08 : 0.92)
                    .opacity(pulse ? 1 : 0.75)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: pulse
                    )
            }
            .onAppear {
                
                // Start pulse animation
                pulse = true
                
                // Navigate after 3 sec
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut) {
                        showHome = true
                    }
                }
            }
        }
    }
}

#Preview {
    Loading()
}
