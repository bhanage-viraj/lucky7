//
//  WeeklyAnalyticScreen.swift
//  lucky7
//
//  Created by Ida Bagus Putu Ryan Paramasatya Putra on 02/06/26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct WeeklyAnalyticScreen: View {
    var videoFrames: [UIImage] = []
    
    private var displayFrame: [UIImage] {
        guard !videoFrames.isEmpty else { return [] }
        
        if videoFrames.count <= 3 {
            return videoFrames
        }
        
        let firstFrame = videoFrames.first!
        let middleFrame = videoFrames[videoFrames.count / 2]
        let lastFrame = videoFrames.last!

        return [firstFrame, middleFrame, lastFrame]
    }

    // Placeholder week summary until real weekly aggregation is wired up.
    private let weekRangeLabel = "24 - 30 May 2026"
    private let weekTotalDuration: TimeInterval = 12 * 3600 + 30 * 60

    var sessionStats = [
        ["title1": "FOCUS DURATION",
         "value1": "6h 48m",
         "title2": "DISTRACTED DURATION",
         "value2": "1h 08m"],
        ["title1": "AVG SESSION LENGTH",
         "value1": "68.5 minutes",
         "title2": "AVG DISTRACTED LENGTH",
         "value2": "3.7 minutes"],
        ["title1": "SESSION COMPLETED",
         "value1": "7 times",
         "title2": "DISTRACTED FREQUENCY",
         "value2": "19 times"],
    ]
    
    var body: some View {
            ZStack{
                Color("CanvasBlue")
                    .ignoresSafeArea()
                
                Image("PatternBackground")
                    .ignoresSafeArea()
                    .offset(y: 5)
                
                ScrollView{
                    VStack{
                        Color.clear
                            .frame(height: 24)
                        
                        HStack{
                            Text(weekRangeLabel)
                            Image(systemName: "chevron.down")
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.black)
                                .opacity(0.25)
                        )
                        
                        Color.clear
                            .frame(height: 24)
                        
                        VStack{
                            Text("Total Session Time")
                                .font(.custom("Special Gothic Expanded One", size: 14))
                            
                            ZStack{
                                ZStack {
                                    ForEach([CGPoint(x: -2, y: -2), CGPoint(x: 0, y: -2), CGPoint(x: 2, y: -2),
                                             CGPoint(x: -2, y: 0),                         CGPoint(x: 2, y: 0),
                                             CGPoint(x: -2, y: 2),  CGPoint(x: 0, y: 2),  CGPoint(x: 2, y: 2)], id: \.self) { p in
                                        Text("12h 30m")
                                            .offset(x: p.x, y: p.y)
                                    }
                                    Text("12h 30m")
                                }
                                .foregroundColor(.black)
                                .font(.custom("Special Gothic Expanded One", size: 50))
                                .offset(y: 4)
                                
                                ZStack {
                                    ForEach([CGPoint(x: -2, y: -2), CGPoint(x: 0, y: -2), CGPoint(x: 2, y: -2),
                                             CGPoint(x: -2, y: 0),                         CGPoint(x: 2, y: 0),
                                             CGPoint(x: -2, y: 2),  CGPoint(x: 0, y: 2),  CGPoint(x: 2, y: 2)], id: \.self) { p in
                                        Text("12h 30m")
                                            .foregroundColor(.black)
                                            .offset(x: p.x, y: p.y)
                                    }
                                    Text("12h 30m")
                                }
                                .font(.custom("Special Gothic Expanded One", size: 50))
                            }
                        }
                        .foregroundStyle(.white)
                        
                        Color.clear
                            .frame(height: 24)
                        
                        ZStack(alignment: .top) {
                            Color.white
                                .cornerRadius(24)
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black, lineWidth: 1))
                                .padding(.top, 12)
                                .frame(height: 280)
                            
                            VStack{
                                Spacer()
                                
                                VStack{
                                    ForEach(Array(sessionStats.enumerated()), id: \.offset) { index, stat in
                                        HStack{
                                            VStack(alignment: .center){
                                                Text(stat["title1"] ?? "")
                                                    .font(.system(size: 10))
                                                Text(stat["value1"] ?? "")
                                                    .font(.custom("Special Gothic Expanded One", size: index < 1 ? 28 : 16))
                                            }
                                            .frame(width: 156)
                                            
                                            VStack(alignment: .center){
                                                Text(stat["title2"] ?? "")
                                                    .font(.system(size: 10))
                                                Text(stat["value2"] ?? "")
                                                    .font(.custom("Special Gothic Expanded One", size: index < 1 ? 28 : 16))
                                            }
                                            .frame(width: 156)
                                        }
                                        .padding(.bottom, 12)
                                    }
                                }
                            }
                            .padding()
                            
                            NavigationLink(destination: WrappedVideoScreen(
                                kind: .weekly(
                                    title: "Weekly Rewind",
                                    periodLabel: weekRangeLabel,
                                    duration: weekTotalDuration
                                ),
                                videoFrames: videoFrames
                            )) {
                                ZStack{
                                    SnapshotsView(images: displayFrame)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .offset(y: -76)
                                    
                                    VStack{
                                        Image(systemName: "play.fill")
                                            .foregroundStyle(.black)
                                    }
                                    .zIndex(1)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        Circle()
                                            .fill(.white)
                                            .shadow(color: .black, radius: 0, x: 0, y: 4)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.black, lineWidth: 1)
                                            )
                                    )
                                    .offset(y: -32)
                                }
                            }
                        }
                        
                        CardInput(title: "WHAT YOUR WEEK LOOK LIKE?", backgroundColor: .white) {
                            BarChartView(data: [
                                BarChartData(label: "M", primary: 80, secondary: 10),
                                BarChartData(label: "T", primary: 40, secondary: 18),
                                BarChartData(label: "W", primary: 0,  secondary: 0),
                                BarChartData(label: "T", primary: 100, secondary: 22),
                                BarChartData(label: "F", primary: 30, secondary: 18),
                                BarChartData(label: "S", primary: 88, secondary: 10),
                            ])
                            .frame(height: 300)
                            .padding(24)
                        }
                        .padding(.top, 12)
                        
                        HStack{
                            ZStack{
                                Color.white
                                    .cornerRadius(24)
                                    .shadow(color: .black, radius: 0, x: 0, y: 4)
                                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black, lineWidth: 1))
                                    .padding(.top, 12)
                                    .frame(height: 78)
                                
                                VStack(){
                                    Text("MOST FOCUSED DAY")
                                        .font(.system(size: 10))
                                    
                                    Text("Tuesday")
                                        .font(.custom("Special Gothic Expanded One", size: 15))
                                        .padding(.top, 1)
                                }
                                .offset(y: 8)
                            }
                            
                            ZStack{
                                Color.white
                                    .cornerRadius(24)
                                    .shadow(color: .black, radius: 0, x: 0, y: 4)
                                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black, lineWidth: 1))
                                    .padding(.top, 12)
                                    .frame(height: 78)
                                
                                VStack(){
                                    Text("LEAST FOCUSED DAY")
                                        .font(.system(size: 10))
                                    
                                    Text("Wednesday")
                                        .font(.custom("Special Gothic Expanded One", size: 15))
                                        .padding(.top, 1)
                                }
                                .offset(y: 8)
                            }
                        }
                        
                        CardInput(title: "MOST DISTRACTING APPS", backgroundColor: .white) {
                            VStack(spacing: 0) {
                                ForEach(0..<3) { index in
                                    HStack {
                                        HStack(spacing: 16) {
                                            Text("\(index + 1)")
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 32))
                                            Text("Tiktok")
                                                .font(.custom("Special Gothic Expanded One", size: 15))
                                        }
                                        Spacer()
                                        Text("31 mins")
                                    }
                                    .padding()

                                    if index < 2 {
                                        Divider()
                                    }
                                }
                            }
                            .padding()
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 24)
            }
    }
}

#Preview {
    let dummyFrames = ["dummySnapshot1", "dummySnapshot2", "dummySnapshot3"]
        .compactMap { UIImage(named: $0) }

    NavigationStack {
        WeeklyAnalyticScreen(videoFrames: dummyFrames)
    }
    .modelContainer(for: Session.self, inMemory: true)
}
