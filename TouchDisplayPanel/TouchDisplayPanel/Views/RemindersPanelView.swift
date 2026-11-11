import SwiftUI

struct RemindersPanelView: View {
    @EnvironmentObject private var reminders: RemindersService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            switch reminders.authorizationStatus {
            case .notDetermined:
                permissionPrompt
            case .denied, .restricted:
                deniedView
            case .fullAccess, .writeOnly, .authorized:
                listContent
            @unknown default:
                listContent
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PanelTheme.strip)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reminders")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PanelTheme.textPrimary)
                Text(reminders.filterSummary)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if reminders.isLoading {
                ProgressView()
                    .controlSize(.regular)
                    .tint(PanelTheme.accent)
            }
        }
    }

    private var permissionPrompt: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reminders access is needed to show today’s tasks on this panel.")
                .font(.system(size: 17, design: .rounded))
                .foregroundStyle(PanelTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await reminders.requestAccess() }
            } label: {
                Text("Allow Reminders Access")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(PanelTheme.background)
                    .frame(maxWidth: .infinity, minHeight: PanelTheme.tapMin)
                    .background(PanelTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    private var deniedView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reminders access is off.")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(PanelTheme.textPrimary)
            Text("Enable it in System Settings → Privacy & Security → Reminders, then reopen the app.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(PanelTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                reminders.openSystemSettingsForReminders()
            } label: {
                Text("Open System Settings")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(PanelTheme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: PanelTheme.tapMin)
                    .background(PanelTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var listContent: some View {
        if let error = reminders.lastError {
            Text(error)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(PanelTheme.danger)
        }

        if reminders.reminders.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("No matching reminders.")
                    .font(.system(size: 18, design: .rounded))
                    .foregroundStyle(PanelTheme.textSecondary)
                Text("Showing incomplete items that are due today/overdue, flagged, or undated.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(PanelTheme.textSecondary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    reminders.openRemindersApp()
                } label: {
                    Text("Open Reminders")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(PanelTheme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: PanelTheme.tapMin)
                        .background(PanelTheme.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.top, 20)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(reminders.reminders) { item in
                        ReminderRowView(
                            item: item,
                            onToggle: { reminders.toggleCompleted(item) },
                            onOpen: { reminders.open(item) }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct ReminderRowView: View {
    let item: ReminderItem
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: "circle")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(item.isOverdue ? PanelTheme.danger : PanelTheme.accent)
                    .frame(width: PanelTheme.tapMin, height: PanelTheme.tapMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark \(item.title) complete")

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(PanelTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        if item.isFlagged {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(PanelTheme.remindersFlag)
                        }
                    }

                    HStack(spacing: 8) {
                        if let dueLabel = item.dueLabel {
                            Text(dueLabel)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(item.isOverdue ? PanelTheme.danger : PanelTheme.textSecondary)
                        }
                        if let listName = item.listName {
                            Text(listName)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(PanelTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.title)
            .accessibilityHint("Opens in Reminders")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: PanelTheme.tapMin, alignment: .leading)
        .background(PanelTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
