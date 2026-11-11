import AppKit
import Combine
import EventKit
import Foundation
import SwiftUI

struct CalendarEventItem: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarName: String?
    let color: Color
    let eventIdentifier: String
    let conferenceURL: URL?

    var hasConferenceURL: Bool { conferenceURL != nil }

    var timeLabel: String {
        if isAllDay { return "All day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startDate))–\(formatter.string(from: endDate))"
    }
}

@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var events: [CalendarEventItem] = []
    @Published private(set) var nextEventID: String?
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var dayLabel: String = ""
    /// Bumped on manual refresh so the timeline can scroll back to now.
    @Published private(set) var refreshGeneration: UInt = 0

    private let store = EKEventStore()
    private var dayChangeCancellable: AnyCancellable?
    private var periodicRefreshCancellable: AnyCancellable?
    private var storeChangedObserver: NSObjectProtocol?
    private var loadingFeedbackTask: Task<Void, Never>?

    /// Light poll so the next-meeting highlight and day window stay current across midnight.
    private static let periodicRefreshInterval: TimeInterval = 60
    private static let manualLoadingFeedbackNanoseconds: UInt64 = 350_000_000

    func start() {
        authorizationStatus = Self.currentStatus()
        updateDayLabel()
        observeDayChange()
        observeStoreChanges()
        observePeriodicRefresh()
        if Self.hasReadAccess(authorizationStatus) {
            refreshEvents()
        }
    }

    deinit {
        if let storeChangedObserver {
            NotificationCenter.default.removeObserver(storeChangedObserver)
        }
        loadingFeedbackTask?.cancel()
    }

    func requestAccess() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            authorizationStatus = Self.currentStatus()
            if granted || Self.hasReadAccess(authorizationStatus) {
                refreshEvents()
            } else {
                lastError = "Calendar access was not granted."
            }
        } catch {
            lastError = error.localizedDescription
            authorizationStatus = Self.currentStatus()
        }
    }

    /// Part of the global touch Refresh: reload today’s events and scroll the timeline to now.
    func refreshFromUser() {
        guard Self.hasReadAccess(authorizationStatus) else { return }
        guard !isLoading else { return }
        refreshEvents(userInitiated: true)
    }

    func refreshEvents(userInitiated: Bool = false) {
        guard Self.hasReadAccess(authorizationStatus) else { return }

        if userInitiated {
            loadingFeedbackTask?.cancel()
            isLoading = true
        }

        lastError = nil
        updateDayLabel()

        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else {
            if userInitiated { finishManualLoadingFeedback() }
            return
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        let mapped = ekEvents.map { Self.map($0) }
        events = mapped
        nextEventID = Self.resolveNextEventID(in: mapped, now: Date())

        if userInitiated {
            refreshGeneration &+= 1
            finishManualLoadingFeedback()
        }
    }

    private func finishManualLoadingFeedback() {
        loadingFeedbackTask?.cancel()
        loadingFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.manualLoadingFeedbackNanoseconds)
            guard !Task.isCancelled else { return }
            isLoading = false
        }
    }

    func open(_ event: CalendarEventItem) {
        if let url = event.conferenceURL {
            NSWorkspace.shared.open(url)
            return
        }
        // Calendar URL scheme for a specific event.
        let encoded = event.eventIdentifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? event.eventIdentifier
        if let url = URL(string: "ical://ekevent/\(encoded)") {
            if NSWorkspace.shared.open(url) { return }
        }
        if let url = URL(string: "ical://") {
            NSWorkspace.shared.open(url)
        }
    }

    func openSystemSettingsForCalendar() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars"
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
                self?.refreshEvents()
            }
    }

    private func observePeriodicRefresh() {
        periodicRefreshCancellable = Timer.publish(
            every: Self.periodicRefreshInterval,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            self?.refreshEvents()
        }
    }

    private func observeStoreChanges() {
        storeChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshEvents()
            }
        }
    }

    private func updateDayLabel() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        dayLabel = formatter.string(from: Date())
    }

    private static func currentStatus() -> EKAuthorizationStatus {
        if #available(macOS 14.0, *) {
            return EKEventStore.authorizationStatus(for: .event)
        } else {
            return EKEventStore.authorizationStatus(for: .event)
        }
    }

    private static func hasReadAccess(_ status: EKAuthorizationStatus) -> Bool {
        switch status {
        case .fullAccess, .authorized:
            return true
        case .writeOnly:
            // Write-only cannot list events; treat as needing full access.
            return false
        default:
            return false
        }
    }

    private static func resolveNextEventID(in events: [CalendarEventItem], now: Date) -> String? {
        events.first { item in
            if item.isAllDay { return false }
            return item.endDate > now
        }?.id
    }

    private static func map(_ event: EKEvent) -> CalendarEventItem {
        let cgColor = event.calendar.cgColor ?? CGColor(gray: 0.5, alpha: 1)
        let nsColor = NSColor(cgColor: cgColor) ?? .systemGray
        let titleValue = event.title ?? ""
        let rawTitle = titleValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return CalendarEventItem(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: rawTitle.isEmpty ? "(No title)" : rawTitle,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            calendarName: event.calendar.title,
            color: Color(nsColor: nsColor),
            eventIdentifier: event.eventIdentifier ?? "",
            conferenceURL: extractConferenceURL(from: event)
        )
    }

    /// Prefer structured URL, then scan location / notes for Meet / Zoom / Teams links.
    private static func extractConferenceURL(from event: EKEvent) -> URL? {
        if let url = event.url, isConferenceURL(url) {
            return url
        }
        let blobs = [event.location, event.notes].compactMap { $0 }
        for blob in blobs {
            if let url = firstURL(in: blob), isConferenceURL(url) {
                return url
            }
        }
        for blob in blobs {
            if let url = firstURL(in: blob) {
                return url
            }
        }
        return event.url
    }

    private static func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.url
    }

    private static func isConferenceURL(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let absolute = url.absoluteString.lowercased()
        let markers = [
            "meet.google.com",
            "zoom.us",
            "zoom.com",
            "teams.microsoft.com",
            "teams.live.com",
            "webex.com",
            "facetime.apple.com"
        ]
        return markers.contains { host.contains($0) || absolute.contains($0) }
    }
}
