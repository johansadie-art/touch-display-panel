import Foundation

/// Classic calendar day-view packing: overlapping events get adjacent columns (lanes).
struct TimelineLaidOutEvent: Identifiable, Equatable {
    var id: String { event.id }
    let event: CalendarEventItem
    /// 0-based lane within the collision cluster.
    let column: Int
    /// Total lanes in the collision cluster (shared width divisor).
    let columnCount: Int
}

enum DayTimelineLayout {
    /// Minutes from `dayStart` used as the vertical origin for timed events.
    static let defaultVisibleStartMinute = 6 * 60
    /// Exclusive end of the default day window (22:00).
    static let defaultVisibleEndMinute = 22 * 60

    /// Pack timed (non–all-day) events into overlap lanes.
    static func layoutLanes(_ events: [CalendarEventItem]) -> [TimelineLaidOutEvent] {
        let timed = events
            .filter { !$0.isAllDay }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                // Longer events first so shorter ones nest into free lanes more cleanly.
                if lhs.endDate != rhs.endDate {
                    return lhs.endDate > rhs.endDate
                }
                return lhs.id < rhs.id
            }

        guard !timed.isEmpty else { return [] }

        var result: [TimelineLaidOutEvent] = []
        var cluster: [CalendarEventItem] = []
        var clusterEnd = Date.distantPast

        for event in timed {
            if !cluster.isEmpty, event.startDate >= clusterEnd {
                result.append(contentsOf: assignColumns(cluster))
                cluster.removeAll(keepingCapacity: true)
                clusterEnd = .distantPast
            }
            cluster.append(event)
            if event.endDate > clusterEnd {
                clusterEnd = event.endDate
            }
        }

        if !cluster.isEmpty {
            result.append(contentsOf: assignColumns(cluster))
        }
        return result
    }

    /// Visible minute range expanded to fit events; falls back to 06:00–22:00.
    static func visibleMinuteRange(
        events: [CalendarEventItem],
        dayStart: Date,
        calendar: Calendar = .current
    ) -> Range<Int> {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
        let timed = events.filter { !$0.isAllDay }
        guard !timed.isEmpty else {
            return defaultVisibleStartMinute..<defaultVisibleEndMinute
        }

        var earliest = defaultVisibleStartMinute
        var latest = defaultVisibleEndMinute

        for event in timed {
            let start = clamp(event.startDate, dayStart: dayStart, dayEnd: dayEnd)
            let end = clamp(event.endDate, dayStart: dayStart, dayEnd: dayEnd)
            earliest = min(earliest, minutesFromDayStart(start, dayStart: dayStart))
            latest = max(latest, minutesFromDayStart(end, dayStart: dayStart))
        }

        // Snap out to hour boundaries with a little padding.
        let startMinute = max(0, (earliest / 60) * 60)
        let endMinute = min(24 * 60, ((latest + 59) / 60) * 60)
        if endMinute <= startMinute {
            return defaultVisibleStartMinute..<defaultVisibleEndMinute
        }
        return startMinute..<endMinute
    }

    static func minutesFromDayStart(_ date: Date, dayStart: Date) -> Int {
        Int((date.timeIntervalSince(dayStart) / 60.0).rounded(.down))
    }

    static func clamp(_ date: Date, dayStart: Date, dayEnd: Date) -> Date {
        min(max(date, dayStart), dayEnd)
    }

    // MARK: - Private

    private static func assignColumns(_ cluster: [CalendarEventItem]) -> [TimelineLaidOutEvent] {
        var columnEnds: [Date] = []
        var placements: [(CalendarEventItem, Int)] = []

        for event in cluster {
            var placedColumn: Int?
            for index in columnEnds.indices where columnEnds[index] <= event.startDate {
                placedColumn = index
                columnEnds[index] = event.endDate
                break
            }
            if let placedColumn {
                placements.append((event, placedColumn))
            } else {
                placements.append((event, columnEnds.count))
                columnEnds.append(event.endDate)
            }
        }

        let columnCount = max(columnEnds.count, 1)
        return placements.map { event, column in
            TimelineLaidOutEvent(event: event, column: column, columnCount: columnCount)
        }
    }
}
