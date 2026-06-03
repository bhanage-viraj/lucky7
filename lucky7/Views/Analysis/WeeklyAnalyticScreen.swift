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
    /// The sessions that fall in this week (passed in from the history screen).
    var sessions: [Session] = []
    /// First day of the week these stats describe.
    var weekStart: Date = Date()
    var videoFrames: [UIImage] = []

    /// All recorded distractions; filtered down to this week's sessions below.
    @Query private var allDistractions: [Distraction]

    private let calendar = Calendar.current

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

    // MARK: - Weekly aggregation

    private var sessionIDs: Set<UUID> { Set(sessions.map(\.id)) }

    private var weekDistractions: [Distraction] {
        allDistractions.filter { sessionIDs.contains($0.sessionId) }
    }

    private var weekTotalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.actualDuration }
    }

    private var totalDistracted: TimeInterval {
        weekDistractions.reduce(0) { $0 + $1.distractionDuration }
    }

    private var totalFocus: TimeInterval {
        max(weekTotalDuration - totalDistracted, 0)
    }

    private var avgSessionLength: TimeInterval {
        sessions.isEmpty ? 0 : weekTotalDuration / Double(sessions.count)
    }

    private var avgDistractedLength: TimeInterval {
        weekDistractions.isEmpty ? 0 : totalDistracted / Double(weekDistractions.count)
    }

    private var totalSessionTimeText: String {
        TimeFormatter.shortDuration(weekTotalDuration)
    }

    private var weekRangeLabel: String {
        let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        if calendar.isDate(weekStart, equalTo: end, toGranularity: .month) {
            return "\(formatted(weekStart, "d")) - \(formatted(end, "d MMMM yyyy"))"
        } else if calendar.isDate(weekStart, equalTo: end, toGranularity: .year) {
            return "\(formatted(weekStart, "d MMM")) - \(formatted(end, "d MMM yyyy"))"
        } else {
            return "\(formatted(weekStart, "d MMM yyyy")) - \(formatted(end, "d MMM yyyy"))"
        }
    }

    private var sessionStats: [[String: String]] {
        [
            ["title1": "FOCUS DURATION",
             "value1": TimeFormatter.shortDuration(totalFocus),
             "title2": "DISTRACTED DURATION",
             "value2": TimeFormatter.shortDuration(totalDistracted)],
            ["title1": "AVG SESSION LENGTH",
             "value1": minutesText(avgSessionLength),
             "title2": "AVG DISTRACTED LENGTH",
             "value2": minutesText(avgDistractedLength)],
            ["title1": "SESSION COMPLETED",
             "value1": "\(sessions.count) times",
             "title2": "DISTRACTED FREQUENCY",
             "value2": "\(weekDistractions.count) times"],
        ]
    }

    /// Per-day focus / distracted split for the seven days of the week.
    private var dayStats: [DayStat] {
        (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            let daySessions = sessions.filter { calendar.isDate($0.startTime, inSameDayAs: day) }
            let dayIDs = Set(daySessions.map(\.id))
            let distracted = weekDistractions
                .filter { dayIDs.contains($0.sessionId) }
                .reduce(0) { $0 + $1.distractionDuration }
            let total = daySessions.reduce(0) { $0 + $1.actualDuration }
            return DayStat(
                date: day,
                focusMinutes: max(total - distracted, 0) / 60,
                distractedMinutes: distracted / 60,
                hasSessions: !daySessions.isEmpty
            )
        }
    }

    private var weekdayBars: [BarChartData] {
        dayStats.map {
            BarChartData(label: formatted($0.date, "EEEEE"),
                         primary: $0.focusMinutes,
                         secondary: $0.distractedMinutes)
        }
    }

    /// Scales the chart axis to the busiest day, in 30-minute steps (min 2h).
    private var chartConfig: BarChartConfig {
        var config = BarChartConfig()
        let maxMinutes = dayStats.map { $0.focusMinutes + $0.distractedMinutes }.max() ?? 0
        let step = max(30, Int(ceil(maxMinutes / 4 / 30)) * 30)
        let top = step * 4
        config.maxValue = Double(top)
        config.gridLines = [top, top - step, top - 2 * step, top - 3 * step, 0]
        return config
    }

    private var mostFocusedDayText: String {
        guard let best = dayStats.filter({ $0.hasSessions })
            .max(by: { $0.focusMinutes < $1.focusMinutes }) else { return "—" }
        return formatted(best.date, "EEEE")
    }

    private var leastFocusedDayText: String {
        guard let worst = dayStats.filter({ $0.hasSessions })
            .min(by: { $0.focusMinutes < $1.focusMinutes }) else { return "—" }
        return formatted(worst.date, "EEEE")
    }

    /// The three apps that ate the most time this week.
    private var topDistractingApps: [(name: String, duration: TimeInterval)] {
        Dictionary(grouping: weekDistractions, by: { $0.appOpened })
            .map { (name: $0.key, duration: $0.value.reduce(0) { $0 + $1.distractionDuration }) }
            .sorted { $0.duration > $1.duration }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Formatting helpers

    private func formatted(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private func minutesText(_ seconds: TimeInterval) -> String {
        String(format: "%.1f minutes", seconds / 60)
    }

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
                                        Text(totalSessionTimeText)
                                            .offset(x: p.x, y: p.y)
                                    }
                                    Text(totalSessionTimeText)
                                }
                                .foregroundColor(.black)
                                .font(.custom("Special Gothic Expanded One", size: 50))
                                .offset(y: 4)
                                
                                ZStack {
                                    ForEach([CGPoint(x: -2, y: -2), CGPoint(x: 0, y: -2), CGPoint(x: 2, y: -2),
                                             CGPoint(x: -2, y: 0),                         CGPoint(x: 2, y: 0),
                                             CGPoint(x: -2, y: 2),  CGPoint(x: 0, y: 2),  CGPoint(x: 2, y: 2)], id: \.self) { p in
                                        Text(totalSessionTimeText)
                                            .foregroundColor(.black)
                                            .offset(x: p.x, y: p.y)
                                    }
                                    Text(totalSessionTimeText)
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
                            
                            // TODO(analytics): WrappedVideoScreen was refactored to init(sessionId:),
                            // but a weekly rewind has no single session. Temporary stub so main compiles —
                            // the weekly/monthly rewind needs reworking against the new API (owner: analytics).
                            NavigationLink(destination: WrappedVideoScreen(
                                sessionId: UUID(),
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
                            BarChartView(data: weekdayBars, config: chartConfig)
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

                                    Text(mostFocusedDayText)
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

                                    Text(leastFocusedDayText)
                                        .font(.custom("Special Gothic Expanded One", size: 15))
                                        .padding(.top, 1)
                                }
                                .offset(y: 8)
                            }
                        }
                        
                        CardInput(title: "MOST DISTRACTING APPS", backgroundColor: .white) {
                            VStack(spacing: 0) {
                                if topDistractingApps.isEmpty {
                                    Text("No distractions this week 🎉")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 32)
                                } else {
                                    ForEach(Array(topDistractingApps.enumerated()), id: \.offset) { index, app in
                                        HStack {
                                            HStack(spacing: 16) {
                                                Text("\(index + 1)")
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 32))
                                                Text(app.name)
                                                    .font(.custom("Special Gothic Expanded One", size: 15))
                                            }
                                            Spacer()
                                            Text(TimeFormatter.shortDuration(app.duration))
                                        }
                                        .padding()

                                        if index < topDistractingApps.count - 1 {
                                            Divider()
                                        }
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

// MARK: - Per-day model

private struct DayStat {
    let date: Date
    let focusMinutes: Double
    let distractedMinutes: Double
    let hasSessions: Bool
}

#Preview {
    let dummyFrames = ["dummySnapshot1", "dummySnapshot2", "dummySnapshot3"]
        .compactMap { UIImage(named: $0) }

    let calendar = Calendar.current
    let now = Date()
    let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    let sampleSessions: [Session] = (0..<4).map { offset in
        let start = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
        return Session(
            userId: UUID(),
            duration: 3600,
            startTime: start,
            endTime: start.addingTimeInterval(TimeInterval(3600 + offset * 600)),
            title: "Session \(offset + 1)"
        )
    }

    return NavigationStack {
        WeeklyAnalyticScreen(
            sessions: sampleSessions,
            weekStart: weekStart,
            videoFrames: dummyFrames
        )
    }
    .modelContainer(for: [Session.self, Distraction.self], inMemory: true)
}
