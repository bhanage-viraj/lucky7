//
//  SessionHistory.swift
//  lucky7
//
//  Created by Kadek Belvanatha Gargita Satwikananda on 30/05/26.
//

import SwiftUI
import SwiftData

// Video-template frames used as day thumbnails (stand-in until real
// per-session video frames are captured).
private let templateFrames = ["dummySnapshot1", "dummySnapshot2", "dummySnapshot3"]

/// Deterministic-but-varied template frame for a given day.
private func templateFrame(for date: Date) -> String {
    let cal = Calendar.current
    let day = cal.component(.day, from: date)
    let month = cal.component(.month, from: date)
    return templateFrames[(day + month) % templateFrames.count]
}

struct HistoryView: View {
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]

    /// Last 12 months, current month first.
    private var months: [Date] {
        let cal = Calendar.current
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        return (0..<12).compactMap { cal.date(byAdding: .month, value: -$0, to: startOfThisMonth) }
    }

    /// Start-of-day dates that have at least one session.
    private var activeDays: Set<Date> {
        Set(sessions.map { Calendar.current.startOfDay(for: $0.startTime) })
    }

    var body: some View {
        ZStack {
            Color("CanvasBlue")
                .ignoresSafeArea()

            Image("PatternBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .offset(y: -30)

            VStack(spacing: 0) {
                header
                calendarScroll
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            Spacer()

            Text("History")
                .font(.custom("Special Gothic Expanded One", size: 20))
                .foregroundColor(.white)

            Spacer()

            Button(action: {}) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }

    // MARK: - Calendar

    private var calendarScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                ForEach(months, id: \.self) { month in
                    MonthCalendarCard(monthDate: month, activeDays: activeDays)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Search tab (Tab(role: .search) content)
struct SessionSearchView: View {
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @State private var searchText = ""

    /// Sessions whose title matches the search query.
    private var searchResults: [Session] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("CanvasBlue")
                    .ignoresSafeArea()

                Image("PatternBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .offset(y: -30)

                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    placeholderState
                } else if searchResults.isEmpty {
                    emptyState
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(text: $searchText, prompt: "Search session title")
    }

    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(searchResults) { session in
                    SearchResultRow(session: session)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    private var placeholderState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
            Text("Search your sessions by title")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 32)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
            Text("No sessions match “\(searchText)”")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.white.opacity(0.8))
        .padding(.horizontal, 32)
    }
}

// MARK: - Reusable Month Card
struct MonthCalendarCard: View {
    let monthDate: Date          // first day of the month
    let activeDays: Set<Date>    // start-of-day dates that have sessions

    private let cal = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthDate).uppercased()
    }

    private var daysCount: Int {
        cal.range(of: .day, in: .month, for: monthDate)?.count ?? 30
    }

    /// Number of empty leading cells (0 = month starts on Sunday).
    private var startOffset: Int {
        cal.component(.weekday, from: monthDate) - 1
    }

    /// Single flat list of grid cells: leading `nil`s (empty) followed by day
    /// numbers. Indexed identity avoids the ForEach id collision that dropped
    /// the first days of months starting mid-week.
    private var gridCells: [Int?] {
        Array(repeating: nil, count: startOffset) + (1...daysCount).map { Optional($0) }
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                ForEach(Array(daysOfWeek.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.custom("Special Gothic Expanded One", size: 10))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 30) // Space for the overlapping pill

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(gridCells.enumerated()), id: \.offset) { _, cell in
                    if let day = cell {
                        let date = cal.date(byAdding: .day, value: day - 1, to: monthDate) ?? monthDate
                        let hasSession = activeDays.contains(cal.startOfDay(for: date))
                        DayCell(day: day, hasSession: hasSession, frameName: templateFrame(for: date))
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black)
                        .offset(y: 4)
                )
        )
        .overlay(alignment: .top) {
            Text(monthYear)
                .font(.custom("Special Gothic Expanded One", size: 10))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black))
                .offset(y: -14)
        }
    }
}

// MARK: - Individual Day Cell
struct DayCell: View {
    var day: Int
    var hasSession: Bool
    var frameName: String

    var body: some View {
        ZStack {
            if hasSession {
                Image(frameName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(white: 0.9))
                    .frame(width: 40, height: 40)
            }

            Text(String(format: "%02d", day))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(hasSession ? .white : .gray.opacity(0.5))
                .shadow(color: hasSession ? .black.opacity(0.8) : .clear, radius: 2, x: 0, y: 1)
        }
        .frame(height: 44)
    }
}

// MARK: - Search result row
struct SearchResultRow: View {
    let session: Session

    private var thumbnail: Image {
        if let data = session.snapshotImages.first, let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return Image(templateFrame(for: session.startTime))
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title.isEmpty ? "Untitled session" : session.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.15))
        )
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: Session.self, inMemory: true)
}
