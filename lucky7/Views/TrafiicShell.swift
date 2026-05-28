import SwiftUI

struct TrafficShell<Content: View>: View {

    @ViewBuilder var content: () -> Content

    var body: some View {

        ZStack {

            // BACK BODY
            Image("Circle")
                .resizable()
                .scaledToFit()
                .frame(width: 148.92, height: 148.92)

            // CENTER HOLDER
            ZStack {

                Circle()
                    .fill(.black)
                    .frame(width: 100.2, height: 100.2)
                    .shadow(
                        color: .black.opacity(0.15),
                        radius: 4,
                        x: 0,
                        y: 2
                    )

                // CONTENT
                content()
                    .frame(width: 92, height: 92)
                    .clipShape(Circle()) // keeps numbers INSIDE
            }
            .offset(y: -10)

            // TOP OVERLAY
            Image("DottedCircle")
                .resizable()
                .scaledToFit()
                .frame(width: 100.2, height: 100.2)
                .offset(y: -10)
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    
    @Previewable @State var selected = 25
    
    VStack(spacing: 60) {
        
        // SCROLLABLE
        TrafficShell{
            
        }
        // BUTTON
        
    }
    .padding()
    
}
