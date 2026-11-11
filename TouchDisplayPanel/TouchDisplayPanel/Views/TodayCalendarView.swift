import SwiftUI

struct TodayCalendarView: View {
    @EnvironmentObject private var calendar: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            switch calendar.authorizationStatus {
            case .notDetermined:
                permissionPrompt
            case .denied, .restricted:
                deniedView
            case .fullAccess, .writeOnly, .authorized:
                eventsContent
            @unknown default:
                eventsContent
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(PanelTheme.textPrimary)
                Text(calendar.dayLabel)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(PanelTheme.textSecondary)
            }
            Spacer(minLength: 12)
            if canRefresh {
                refreshButton
            }
        }
    }

    private var canRefresh: Bool {
        switch calendar.authorizationStatus {
        case .fullAccess, .authorized:
            return true
        default:
            return false
        }
    }

    private var refreshButton: some View {
        Button {
            calendar.refreshFromUser()
        } label: {
            HStack(spacing: 10) {
                if calendar.isLoading {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(PanelTheme.textPrimary)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20, weight: .semibold))
                }
                Text("Refresh")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(PanelTheme.textPrimary)
            .padding(.horizontal, 22)
            .frame(minHeight: PanelTheme.tapMin)
            .background(PanelTheme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(calendar.isLoading ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .disabled(calendar.isLoading)
        .accessibilityLabel("Refresh calendar")
        .accessibilityHint("Reloads today’s events and scrolls to now")
    }

    private var permissionPrompt: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Calendar access is needed to show today’s meetings on this panel.")
                .font(.system(size: 20, design: .rounded))
                .foregroundStyle(PanelTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await calendar.requestAccess() }
            } label: {
                Text("Allow Calendar Access")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(PanelTheme.background)
                    .frame(minHeight: PanelTheme.tapMin)
                    .padding(.horizontal, 28)
                    .background(PanelTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 24)
    }

    private var deniedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar access is off.")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(PanelTheme.textPrimary)
            Text("Enable it in System Settings → Privacy & Security → Calendars, then reopen the app.")
                .font(.system(size: 18, design: .rounded))
                .foregroundStyle(PanelTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                calendar.openSystemSettingsForCalendar()
            } label: {
                Text("Open System Settings")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(PanelTheme.textPrimary)
                    .frame(minHeight: PanelTheme.tapMin)
                    .padding(.horizontal, 24)
                    .background(PanelTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 24)
    }

    @ViewBuilder
    private var eventsContent: some View {
        if let error = calendar.lastError {
            Text(error)
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(PanelTheme.danger)
        }

        if calendar.events.isEmpty {
            Text("No events today.")
                .font(.system(size: 20, design: .rounded))
                .foregroundStyle(PanelTheme.textSecondary)
                .padding(.top, 32)
        } else {
            DayTimelineView(
                events: calendar.events,
                nextEventID: calendar.nextEventID,
                scrollToNowToken: calendar.refreshGeneration,
                onOpen: { calendar.open($0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Day timeline

private struct DayTimelineView: View {
    let events: [CalendarEventItem]
    let nextEventID: String?
    let scrollToNowToken: UInt
    let onOpen: (CalendarEventItem) -> Void

    /// Vertical scale: ~72pt per hour keeps short meetings touchable after min-height clamp.
    private let pointsPerMinute: CGFloat = 1.2
    private let timeGutterWidth: CGFloat = 72
    private let laneGap: CGFloat = 6
    private let minEventHeight: CGFloat = PanelTheme.tapMin

    private var dayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var allDayEvents: [CalendarEventItem] {
        events.filter(\.isAllDay)
    }

    private var laidOut: [TimelineLaidOutEvent] {
        DayTimelineLayout.layoutLanes(events)
    }

    private var visibleMinutes: Range<Int> {
        DayTimelineLayout.visibleMinuteRange(events: events, dayStart: dayStart)
    }

    private var timelineHeight: CGFloat {
        CGFloat(visibleMinutes.count) * pointsPerMinute
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !allDayEvents.isEmpty {
                allDayStrip
            }

            if laidOut.isEmpty {
                if allDayEvents.isEmpty {
                    Text("No timed events today.")
                        .font(.system(size: 18, design: .rounded))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .padding(.top, 8)
                }
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    GeometryReader { geo in
                        ScrollViewReader { proxy in
                            ScrollView {
                                ZStack(alignment: .topLeading) {
                                    hourGrid(width: geo.size.width)
                                    eventBlocks(width: geo.size.width, now: context.date)
                                    nowLine(width: geo.size.width, now: context.date)

                                    // Anchor near "now" for initial / manual-refresh scroll.
                                    Color.clear
                                        .frame(width: 1, height: 1)
                                        .offset(y: yOffset(for: context.date) - 80)
                                        .id("now-anchor")
                                }
                                .frame(width: geo.size.width, height: timelineHeight, alignment: .topLeading)
                            }
                            .onAppear {
                                DispatchQueue.main.async {
                                    proxy.scrollTo("now-anchor", anchor: .top)
                                }
                            }
                            .onChange(of: scrollToNowToken) { _, _ in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    proxy.scrollTo("now-anchor", anchor: .top)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var allDayStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All day")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(PanelTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allDayEvents) { event in
                        TimelineEventBlock(
                            event: event,
                            isNext: event.id == nextEventID,
                            compact: true
                        ) {
                            onOpen(event)
                        }
                        .frame(minWidth: 180, minHeight: PanelTheme.tapMin)
                    }
                }
            }
        }
    }

    private func hourGrid(width: CGFloat) -> some View {
        let hours = Array(stride(from: visibleMinutes.lowerBound, to: visibleMinutes.upperBound, by: 60))
        return ZStack(alignment: .topLeading) {
            ForEach(hours, id: \.self) { minute in
                let y = CGFloat(minute - visibleMinutes.lowerBound) * pointsPerMinute
                HStack(spacing: 0) {
                    Text(hourLabel(minute))
                        .font(.system(size: 14, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(PanelTheme.textSecondary)
                        .frame(width: timeGutterWidth, alignment: .trailing)
                        .padding(.trailing, 12)

                    Rectangle()
                        .fill(PanelTheme.elevated.opacity(0.9))
                        .frame(height: 1)
                }
                .offset(y: y)
            }
        }
        .frame(width: width, height: timelineHeight, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func eventBlocks(width: CGFloat, now: Date) -> some View {
        let contentWidth = max(width - timeGutterWidth - 8, 120)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        return ZStack(alignment: .topLeading) {
            ForEach(laidOut) { item in
                let start = DayTimelineLayout.clamp(item.event.startDate, dayStart: dayStart, dayEnd: dayEnd)
                let end = DayTimelineLayout.clamp(item.event.endDate, dayStart: dayStart, dayEnd: dayEnd)
                let startMinute = DayTimelineLayout.minutesFromDayStart(start, dayStart: dayStart)
                let endMinute = max(
                    startMinute + 1,
                    DayTimelineLayout.minutesFromDayStart(end, dayStart: dayStart)
                )

                let rawTop = CGFloat(startMinute - visibleMinutes.lowerBound) * pointsPerMinute
                let rawHeight = CGFloat(endMinute - startMinute) * pointsPerMinute
                let height = max(rawHeight, minEventHeight)
                let laneWidth = (contentWidth - laneGap * CGFloat(item.columnCount - 1)) / CGFloat(item.columnCount)
                let x = timeGutterWidth + 8 + CGFloat(item.column) * (laneWidth + laneGap)
                let isPast = item.event.endDate <= now

                TimelineEventBlock(
                    event: item.event,
                    isNext: item.event.id == nextEventID,
                    compact: height < 72
                ) {
                    onOpen(item.event)
                }
                .frame(width: max(laneWidth, 64), height: height, alignment: .topLeading)
                .opacity(isPast && item.event.id != nextEventID ? 0.55 : 1)
                .offset(x: x, y: rawTop)
                .zIndex(Double(startMinute) + Double(item.column) * 0.01)
            }
        }
        .frame(width: width, height: timelineHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func nowLine(width: CGFloat, now: Date) -> some View {
        let minute = DayTimelineLayout.minutesFromDayStart(now, dayStart: dayStart)
        if visibleMinutes.contains(minute) {
            let y = yOffset(for: now)
            HStack(spacing: 0) {
                Circle()
                    .fill(PanelTheme.danger)
                    .frame(width: 10, height: 10)
                    .frame(width: timeGutterWidth, alignment: .trailing)
                    .padding(.trailing, 6)
                Rectangle()
                    .fill(PanelTheme.danger)
                    .frame(height: 2)
            }
            .offset(y: y - 5)
            .frame(width: width, alignment: .leading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func yOffset(for date: Date) -> CGFloat {
        let minute = DayTimelineLayout.minutesFromDayStart(date, dayStart: dayStart)
        return CGFloat(minute - visibleMinutes.lowerBound) * pointsPerMinute
    }

    private func hourLabel(_ minuteOfDay: Int) -> String {
        let hour = minuteOfDay / 60
        return String(format: "%02d:00", hour)
    }
}

// MARK: - Event block

private struct TimelineEventBlock: View {
    let event: CalendarEventItem
    let isNext: Bool
    var compact: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(event.color)
                    .frame(width: 6)

                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    HStack(spacing: 8) {
                        Text(event.isAllDay ? "All day" : event.timeLabel)
                            .font(.system(size: compact ? 13 : 15, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(PanelTheme.textPrimary)
                            .lineLimit(1)

                        if isNext {
                            Text("NEXT")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .foregroundStyle(PanelTheme.background)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(PanelTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }

                        Spacer(minLength: 0)

                        if event.hasConferenceURL {
                            Image(systemName: "video.fill")
                                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                                .foregroundStyle(PanelTheme.accent)
                        }
                    }

                    Text(event.title)
                        .font(.system(size: compact ? 16 : 20, weight: .medium, design: .rounded))
                        .foregroundStyle(PanelTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(compact ? 1 : 3)

                    if !compact, let calendarName = event.calendarName {
                        Text(calendarName)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(PanelTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, compact ? 8 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(isNext ? PanelTheme.accent.opacity(0.14) : PanelTheme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isNext ? PanelTheme.accent.opacity(0.75) : event.color.opacity(0.35), lineWidth: isNext ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(event.timeLabel), \(event.title)")
        .accessibilityHint(event.hasConferenceURL ? "Opens conference link" : "Opens in Calendar")
    }
}
