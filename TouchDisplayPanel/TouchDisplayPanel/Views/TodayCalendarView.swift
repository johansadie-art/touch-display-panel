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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(PanelTheme.textPrimary)
                Text(calendar.dayLabel)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(PanelTheme.textSecondary)
            }
            Spacer()
            if calendar.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(PanelTheme.accent)
            }
        }
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
            Text("No events for the rest of today.")
                .font(.system(size: 20, design: .rounded))
                .foregroundStyle(PanelTheme.textSecondary)
                .padding(.top, 32)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(calendar.events) { event in
                        EventRowView(
                            event: event,
                            isNext: event.id == calendar.nextEventID
                        ) {
                            calendar.open(event)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct EventRowView: View {
    let event: CalendarEventItem
    let isNext: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(event.color)
                    .frame(width: 8)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(event.timeLabel)
                            .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(PanelTheme.textPrimary)
                        if isNext {
                            Text("NEXT")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .tracking(0.6)
                                .foregroundStyle(PanelTheme.background)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(PanelTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        Spacer(minLength: 0)
                        if event.hasConferenceURL {
                            Image(systemName: "video.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(PanelTheme.accent)
                        }
                    }

                    Text(event.title)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(PanelTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if let calendarName = event.calendarName {
                        Text(calendarName)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(PanelTheme.textSecondary)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: PanelTheme.tapMin + 28, alignment: .leading)
            .background(isNext ? PanelTheme.accent.opacity(0.12) : PanelTheme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isNext ? PanelTheme.accent.opacity(0.7) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(event.timeLabel), \(event.title)")
        .accessibilityHint(event.hasConferenceURL ? "Opens conference link" : "Opens in Calendar")
    }
}
