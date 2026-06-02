import SwiftUI

// MARK: - Main View
struct HomePage: View {
    @State private var selectedHours = 2
    @State private var selectedMinutes = 30
    @State private var selected: Int? = 2
    @State private var selected1: Int? = 30
    
    var body: some View {
        NavigationStack {

        ZStack {
            // 1. Background Layer
            BackgroundPatternView()
            
            VStack {
                HeaderView()
                
                Spacer()
                

                ZStack{
                    Image("TrafficPole1")
                        .offset(x:0, y:200)
                        .scaledToFit()
                    .frame(width: 300, height: 300)
                    Image("TrafficPole")
                        
                    VStack{
                        TrafficShell {
                            NumberScroller(selected: $selected)
                        }
                        TrafficShell {
                            NumberScroller(selected: $selected1)
                        }
                        TrafficShell {
                            NavigationLink(destination: RecordingPage(
                                durationSeconds: TimeInterval((selected ?? 0) * 3600 + (selected1 ?? 0) * 60)
                            )) {
                                Text("Enter")
                                    .font(.custom("SpecialGothicExpandedOne-Regular", size: 15))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                            }

                        }
                        
                    }
                    .offset(x:0, y:150)
                    
                    .offset(y: -140)
                       
                    
                }
                .offset(y: -20)
                .frame(width: 200, height: 200)
                
               
                    
                
                    
                
                Spacer()


            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
struct BackgroundPatternView: View {
    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()
            Image("group45")
            
        }
                
    }
}



struct HeaderView: View {
    var body: some View {
        VStack(spacing: 0) {
            
            ZStack {
                
                Image("RushHour")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 420)
                    .offset(y: 50)

                VStack {
                    Spacer()
                    
                    Text("Set your focus duration and timelapse\nspeed before entering Rush Hour")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(1.5)
                        .offset(y: -25) // move text upward/downward
                }
                .frame(height: 220)
                .offset(y: 60)
            }
        }
        .padding(.top, 30)
    }
}


struct TrafficLightCirclePicker: View {
    let label: String
    @Binding var selection: Int
    let range: Range<Int>
    
    var body: some View {
        ZStack {
            // TODO: Add the black circle with inner shadow/borders
            
            VStack {
                // TODO: Add a Wheel Picker for the numbers
                
                // TODO: Add the label text below the picker
            }
        }
    }
}



#Preview {
    HomePage()
}

