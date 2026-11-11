import AppKit
import Combine
import EventKit
import Foundation
import SwiftUI

struct ReminderItem: Identifiable, Equatable {
    let id: String
    let title: String
    let dueLabel: String?
    /// EventKit has no public flagged API; `true` when `EKReminder.priority != 0`.
    let hasPriority: Bool
    let isOverdue: Bool
    let listName: String?
    let calendarItemIdentifier: String
}

/// Incomplete Apple Reminders for the touch panel.
///
/// **Filter (documented default):** incomplete reminders that match any of:
/// - due today or overdue
/// - priority set (`EKReminder.priority != 0` — EventKit has no public `isFlagged`)
/// - undated (no due date) on any Reminder list EventKit can read
///
/// Completed reminders are never shown. Lists respect EventKit access grants.
@MainActor
final class RemindersService: ObservableObject {
    @Published private(set) var reminders: [ReminderItem] = []
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var filterSummary: String =
        "Incomplete · due today/overdue · priority · undated"

    private let store = EKEventStore()
    private var dayChangeCancellable: AnyCancellable?
    private var storeChangedObserver: NSObjectProtocol?

    func start() {
        authorizationStatus = Self.currentStatus()
        observeDayChange()
        observeStoreChanges()
        if Self.hasReadAccess(authorizationStatus) {
            refreshReminders()
        }
    }

    deinit {
        if let storeChangedObserver {
            NotificationCenter.default.removeObserver(storeChangedObserver)
        }
    }

    func requestAccess() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await store.requestFullAccessToReminders()
            } else {
                granted = try await store.requestAccess(to: .reminder)
            }
            authorizationStatus = Self.currentStatus()
            if granted || Self.hasReadAccess(authorizationStatus) {
                refreshReminders()
            } else {
                lastError = "Reminders access was not granted."
            }
        } catch {
            lastError = error.localizedDescription
            authorizationStatus = Self.currentStatus()
        }
    }

    /// Touch-panel Refresh: reload the filtered incomplete Reminders list.
    func refreshFromUser() {
        guard Self.hasReadAccess(authorizationStatus) else { return }
        guard !isLoading else { return }
        refreshReminders(userInitiated: true)
    }

    func refreshReminders(userInitiated: Bool = false) {
        guard Self.hasReadAccess(authorizationStatus) else { return }

        if userInitiated {
            isLoading = true
        }
        lastError = nil

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        store.fetchReminders(matching: predicate) { [weak self] ekReminders in
            Task { @MainActor in
                guard let self else { return }
                defer {
                    if userInitiated {
                        self.isLoading = false
                    }
                }

                let now = Date()
                let cal = Calendar.current
                let startOfToday = cal.startOfDay(for: now)
                let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday)
                    ?? startOfToday.addingTimeInterval(86400)

                let mapped = (ekReminders ?? [])
                    .compactMap { Self.mapIfMatching($0, startOfToday: startOfToday, startOfTomorrow: startOfTomorrow, calendar: cal) }
                    .sorted { lhs, rhs in
                        // Priority first, then overdue, then titled.
                        if lhs.hasPriority != rhs.hasPriority { return lhs.hasPriority && !rhs.hasPriority }
                        if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue && !rhs.isOverdue }
                        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                    }

                self.reminders = mapped
            }
        }
    }

    /// Toggle completion via EventKit; refreshes the panel list afterward.
    func toggleCompleted(_ item: ReminderItem) {
        guard Self.hasWriteAccess(authorizationStatus) else {
            openRemindersApp()
            return
        }
        guard let reminder = store.calendarItem(withIdentifier: item.calendarItemIdentifier) as? EKReminder else {
            lastError = "Could not find that reminder."
            openRemindersApp()
            return
        }

        reminder.isCompleted = !reminder.isCompleted
        if reminder.isCompleted {
            reminder.completionDate = Date()
        } else {
            reminder.completionDate = nil
        }

        do {
            try store.save(reminder, commit: true)
            refreshReminders()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func open(_ item: ReminderItem) {
        // Prefer deep link when possible; fall back to Reminders.app.
        let encoded = item.calendarItemIdentifier
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? item.calendarItemIdentifier
        if let url = URL(string: "x-apple-reminderkit://REMCDReminder/\(encoded)"),
           NSWorkspace.shared.open(url) {
            return
        }
        openRemindersApp()
    }

    func openRemindersApp() {
        if let url = URL(string: "x-apple-reminderkit://"), NSWorkspace.shared.open(url) {
            return
        }
        if let url = URL(string: "reminders://") {
            NSWorkspace.shared.open(url)
        }
    }

    func openSystemSettingsForReminders() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Reminders"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func observeDayChange() {
        dayChangeCancellable = NotificationCenter.default
            .publisher(for: .NSCalendarDayChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshReminders()
            }
    }

    private func observeStoreChanges() {
        storeChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshReminders()
            }
        }
    }

    private static func currentStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    private static func hasReadAccess(_ status: EKAuthorizationStatus) -> Bool {
        switch status {
        case .fullAccess, .authorized:
            return true
        case .writeOnly:
            return false
        default:
            return false
        }
    }

    private static func hasWriteAccess(_ status: EKAuthorizationStatus) -> Bool {
        switch status {
        case .fullAccess, .authorized, .writeOnly:
            return true
        default:
            return false
        }
    }

    private static func mapIfMatching(
        _ reminder: EKReminder,
        startOfToday: Date,
        startOfTomorrow: Date,
        calendar: Calendar
    ) -> ReminderItem? {
        guard !reminder.isCompleted else { return nil }

        let dueDate: Date?
        if let comps = reminder.dueDateComponents {
            dueDate = calendar.date(from: comps)
        } else {
            dueDate = nil
        }

        // EKReminder does not expose Reminders.app “flagged”; priority ≠ none is the supported stand-in.
        let hasPriority = reminder.priority != 0
        let isDueTodayOrOverdue: Bool
        let isOverdue: Bool
        if let dueDate {
            isDueTodayOrOverdue = dueDate < startOfTomorrow
            isOverdue = dueDate < startOfToday
        } else {
            isDueTodayOrOverdue = false
            isOverdue = false
        }

        let isUndated = dueDate == nil
        guard isDueTodayOrOverdue || hasPriority || isUndated else { return nil }

        let titleValue = reminder.title ?? ""
        let rawTitle = titleValue.trimmingCharacters(in: .whitespacesAndNewlines)

        return ReminderItem(
            id: reminder.calendarItemIdentifier,
            title: rawTitle.isEmpty ? "(No title)" : rawTitle,
            dueLabel: dueLabel(for: dueDate, isOverdue: isOverdue, calendar: calendar),
            hasPriority: hasPriority,
            isOverdue: isOverdue,
            listName: reminder.calendar?.title,
            calendarItemIdentifier: reminder.calendarItemIdentifier
        )
    }

    private static func dueLabel(for dueDate: Date?, isOverdue: Bool, calendar: Calendar) -> String? {
        guard let dueDate else { return nil }
        if isOverdue { return "Overdue" }
        if calendar.isDateInToday(dueDate) {
            let comps = calendar.dateComponents([.hour, .minute], from: dueDate)
            if comps.hour != nil || comps.minute != nil {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return "Due \(formatter.string(from: dueDate))"
            }
            return "Due today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "Due \(formatter.string(from: dueDate))"
    }
}
