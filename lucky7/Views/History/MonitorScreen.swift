//
//  MonitorScreen.swift
//  lucky7
//

import SwiftUI
import SwiftData

struct MonitorScreen: View {
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @State private var showSearch = false

    /// Sessions grouped by calendar month (newest first), each month split into real
    /// 7-day weeks. A week that straddles a month boundary is kept whole and filed
    /// under the month most of its sessions fall in, so there's no stray fragment week.
    private var monthGroups: [MonthGroup] {
        let calendar = Calendar.current
        let now = Date()
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start

        // 1. Group sessions into real 7-day calendar weeks.
        let byWeekStart = Dictionary(grouping: sessions) { session -> Date in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start ?? session.startTime
        }

        // 2. For each week, choose the month most of its sessions land in (ties -> later month).
        let pendingWeeks = byWeekStart.map { (weekStart, weekSessions) -> (weekStart: Date, monthStart: Date, sessions: [Session], total: TimeInterval, isCurrent: Bool) in
            let sorted = weekSessions.sorted { $0.startTime > $1.startTime }
            let total = sorted.reduce(0) { $0 + $1.actualDuration }
            let byMonth = Dictionary(grouping: sorted) { session in
                calendar.date(from: calendar.dateComponents([.year, .month], from: session.startTime)) ?? session.startTime
            }
            let monthStart = byMonth.max {
                $0.value.count != $1.value.count ? $0.value.count < $1.value.count : $0.key < $1.key
            }?.key ?? weekStart
            return (weekStart, monthStart, sorted, total, weekStart == currentWeekStart)
        }

        // 3. Bucket weeks by month; number them oldest-first, display newest-first.
        let byMonth = Dictionary(grouping: pendingWeeks) { $0.monthStart }

        return byMonth.keys.sorted(by: >).map { monthStart in
            let weeksAsc = (byMonth[monthStart] ?? []).sorted { $0.weekStart < $1.weekStart }
            let weeks: [WeekGroup] = weeksAsc.enumerated()
                .map { index, week in
                    WeekGroup(
                        id: week.weekStart,
                        number: index + 1,
                        sessions: week.sessions,
                        totalDuration: week.total,
                        isCurrent: week.isCurrent
                    )
                }
                .sorted { $0.id > $1.id }
            let monthTotal = weeksAsc.reduce(0) { $0 + $1.total }
            return MonthGroup(
                id: monthStart,
                weeks: weeks,
                totalDuration: monthTotal,
                isCurrentMonth: monthStart == currentMonthStart
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("CanvasBlue")
                    .ignoresSafeArea()

                Image("PatternBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .offset(y: 10)

                VStack(spacing: 0) {
                    header

                    if monthGroups.isEmpty {
                        emptyState
                    } else {
                        feed
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showSearch) {
                SessionSearchView()
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

            Text("Monitor")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.white)

            Spacer()

            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 20)
    }

    // MARK: - Feed

    private var feed: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(monthGroups) { month in
                    MonthHeader(title: month.title)

                    // The month wrap is only available once the month is complete.
                    if !month.isCurrentMonth && month.totalDuration > 0 {
                        NavigationLink {
                            // TODO(analytics): WrappedVideoScreen was refactored to init(sessionId:),
                            // but a monthly rewind has no single session. Temporary stub so main compiles.
                            WrappedVideoScreen(
                                sessionId: UUID(),
                                videoFrames: month.snapshotFrames
                            )
                        } label: {
                            RewindRow(
                                title: "\(month.rewindName) Rewind",
                                duration: TimeFormatter.shortDuration(month.totalDuration)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(month.weeks) { week in
                        WeekCard(week: week)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "play.tv")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.7))
            Text("No sessions yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text("Your focus sessions will show up here.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Grouping models

struct MonthGroup: Identifiable {
    let id: Date            // first day of the month
    let weeks: [WeekGroup]
    let totalDuration: TimeInterval
    let isCurrentMonth: Bool

    /// "JUNE 2026"
    var title: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: id).uppercased()
    }

    /// "June" — used for the rewind label.
    var rewindName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: id)
    }

    /// Decoded snapshots from every session in the month, used as wrap preview frames.
    var snapshotFrames: [UIImage] {
        weeks.flatMap { $0.snapshotFrames }
    }
}

struct WeekGroup: Identifiable {
    let id: Date            // start of the week
    let number: Int         // sequential position within its month (1 = earliest)
    let sessions: [Session]
    let totalDuration: TimeInterval
    let isCurrent: Bool     // contains today — stays expanded

    var title: String { "Week \(number)" }

    /// Decoded snapshots from every session this week, used as wrap preview frames.
    var snapshotFrames: [UIImage] {
        sessions.flatMap { $0.snapshotImages }.compactMap { UIImage(data: $0) }
    }
}

// MARK: - Week card (collapsible)

struct WeekCard: View {
    let week: WeekGroup
    @State private var userExpanded: Bool

    init(week: WeekGroup) {
        self.week = week
        // Current week starts expanded; past weeks start collapsed.
        _userExpanded = State(initialValue: week.isCurrent)
    }

    /// The current (not-yet-passed) week is always expanded and can't be collapsed.
    private var isExpanded: Bool {
        week.isCurrent ? true : userExpanded
    }

    var body: some View {
        VStack(spacing: 16) {
            Button {
                guard !week.isCurrent else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    userExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)

                    Text(week.title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)

                    Spacer()

                    Text(TimeFormatter.shortDuration(week.totalDuration))
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(week.sessions) { session in
                    NavigationLink {
                        SessionAnalytics(
                            sessionId: session.id,
                            videoFrames: session.snapshotImages.compactMap { UIImage(data: $0) }
                        )
                    } label: {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    WeeklyAnalyticScreen(
                        sessions: week.sessions,
                        weekStart: week.id,
                        videoFrames: week.snapshotFrames
                    )
                } label: {
                    Text("VIEW WEEKLY REWIND")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Color.black))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.20, green: 0.50, blue: 0.93))
                // Neo-brutalist solid shadow
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black)
                        .offset(y: 5)
                )
        )
    }
}

// MARK: - Subcomponents

struct MonthHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black))
            .padding(.top, 8)
    }
}

struct SessionRow: View {
    let session: Session

    private var monthText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: session.startTime).uppercased()
    }

    private var dayText: String {
        String(Calendar.current.component(.day, from: session.startTime))
    }

    private var titleText: String {
        session.title.isEmpty ? "Untitled Session" : session.title
    }

    private var thumbnail: Image? {
        if let data = session.snapshotImages.first, let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 16) {
            // Date column
            VStack(spacing: 2) {
                Text(monthText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                Text(dayText)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.gray)
            }
            .frame(width: 40)

            // Thumbnail (real snapshot if captured, otherwise a placeholder)
            Group {
                if let thumbnail {
                    thumbnail
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.crop.rectangle.fill")
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
                    .lineLimit(2)
                Text(TimeFormatter.longDuration(session.actualDuration))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                // Neo-brutalist solid shadow
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .offset(y: 4)
                )
        )
    }
}

struct RewindRow: View {
    var title: String
    var duration: String

    var body: some View {
        HStack(spacing: 16) {
            // Play Icon
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(.black)
                .padding(10)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(Color.black, lineWidth: 2))

            // Title with outline effect (stacked shadows mimic a hard black stroke)
            Text(title)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 0.5, x: 1, y: 1)
                .shadow(color: .black, radius: 0.5, x: -1, y: -1)
                .shadow(color: .black, radius: 0.5, x: -1, y: 1)
                .shadow(color: .black, radius: 0.5, x: 1, y: -1)

            Spacer()

            Text(duration)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.red, Color.yellow, Color.green],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .offset(y: 4)
                )
        )
    }
}

// MARK: - Preview

@MainActor
func sampleMonitorContainer() -> ModelContainer {
    let container = try! ModelContainer(
        for: Session.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let calendar = Calendar.current
    let now = Date()

    let samples: [(daysAgo: Int, duration: TimeInterval, title: String)] = [
        (0,  3 * 3600 + 20 * 60, "Morning Session Rush!"),
        (1,  3 * 3600 + 20 * 60, "Morning Session Rush!"),
        (2,  3 * 3600 + 20 * 60, "Morning Session Rush!"),
        (9,  2 * 3600 + 10 * 60, "Last Week Grind"),
        (35, 2 * 3600 + 45 * 60, "Late Night Grind"),
        (40, 50 * 60,            "Quick Focus"),
    ]

    for sample in samples {
        let start = calendar.date(byAdding: .day, value: -sample.daysAgo, to: now) ?? now
        context.insert(
            Session(
                userId: UUID(),
                duration: sample.duration,
                startTime: start,
                endTime: start.addingTimeInterval(sample.duration),
                title: sample.title
            )
        )
    }
    try? context.save()

    return container
}

#Preview {
    MonitorScreen()
        .modelContainer(sampleMonitorContainer())
}
