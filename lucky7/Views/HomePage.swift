import SwiftUI

// MARK: - Main View
struct HomePage: View {
    @EnvironmentObject private var sessionTimer: SessionTimerViewModel
    @State private var selectedHours = 2
    @State private var selectedMinutes = 30
    @State private var showRecordingPage = false
    
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
                        
                    VStack(spacing: 12) {
                        
                        TrafficShell {
                            
                            VStack(spacing: 6) {
                                
                                NumberScroller(selected: $selectedHours, range: 0...23)
                                    .frame(height: 55)
                                
                                
                            }
                        }
                        
                        
                        TrafficShell {
                            
                            VStack(spacing: 6) {
                                
                                NumberScroller(selected: $selectedMinutes, range: 1...59)
                                    .frame(height: 55)
                                
                                
                            }
                        }
                        
                        
                        TrafficShell {
                            
                            Button {
                                sessionTimer.configure(hours: selectedHours, minutes: selectedMinutes)
                                showRecordingPage = true
                            } label: {
                                
                                VStack(spacing: 4) {
                                    
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 20))
                                    
                                    Text("ENTER")
                                        .font(.custom("Special Gothic Expanded One", size: 13))
                                }
                                .foregroundStyle(.white)
                            }
                        }
                    }
                    .offset(x: 0, y: 150)
                    .offset(y: -140)
                    .offset(x:0, y:150)
                    
                    .offset(y: -140)
                       
                    
                }
                .offset(y: -30)
                .frame(width: 200, height: 200)
                
               
                    
                
                    
                
                Spacer()
                
                
            }
            .navigationDestination(isPresented: $showRecordingPage) {
                RecordingPage()
                    .hidesFloatingTabBar()
            }
        }
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
        .environmentObject(SessionTimerViewModel())
        .environmentObject(SessionRecordingViewModel())
}

