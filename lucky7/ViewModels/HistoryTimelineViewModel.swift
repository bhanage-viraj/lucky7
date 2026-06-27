import Foundation

enum HistoryTimelineViewModel {
    static func monthGroups(
        from sessions: [Session],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MonthGroup] {
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start

        let byWeekStart = Dictionary(grouping: sessions) { session -> Date in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start ?? session.startTime
        }

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
}
