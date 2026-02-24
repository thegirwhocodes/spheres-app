//
//  CalendarService.swift
//  Spheres - Smart Life Manager
//
//  Calendar integration service using EventKit (supports Apple Calendar + Google Calendar sync)
//  Google Calendar syncs automatically if added to macOS Internet Accounts
//

import SwiftUI
import EventKit

// MARK: - Calendar Provider
enum CalendarProvider: String, CaseIterable {
    case system = "System Calendars"  // Apple Calendar (includes synced Google)
    case googleDirect = "Google Calendar API"

    var icon: String {
        switch self {
        case .system: return "calendar"
        case .googleDirect: return "g.circle.fill"
        }
    }
}

// MARK: - Calendar Service
@MainActor
class CalendarService: ObservableObject {
    static let shared = CalendarService()

    let eventStore = EKEventStore()

    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var calendars: [EKCalendar] = []
    @Published var events: [EKEvent] = []
    @Published var isLoading = false

    // Google Calendar Direct (optional)
    @AppStorage("googleCalendarEnabled") var googleCalendarEnabled = false
    @AppStorage("googleAccessToken") private var googleAccessToken = ""
    @Published var googleEvents: [GoogleCalendarEvent] = []

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus == .fullAccess || authorizationStatus == .authorized {
            loadCalendars()
        }
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                authorizationStatus = granted ? .fullAccess : .denied
                if granted {
                    loadCalendars()
                }
            }
            return granted
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    var hasAccess: Bool {
        authorizationStatus == .fullAccess || authorizationStatus == .authorized
    }

    // MARK: - Calendars
    func loadCalendars() {
        calendars = eventStore.calendars(for: .event)
    }

    var defaultCalendar: EKCalendar? {
        eventStore.defaultCalendarForNewEvents
    }

    // MARK: - Events
    func fetchEvents(from startDate: Date, to endDate: Date) {
        guard hasAccess else { return }

        isLoading = true
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        isLoading = false
    }

    func fetchEventsForDay(_ date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        fetchEvents(from: startOfDay, to: endOfDay)
    }

    func fetchEventsForWeek(containing date: Date) {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }
        fetchEvents(from: weekStart, to: weekEnd)
    }

    // MARK: - Create Events (Time Blocking)
    func createTimeBlock(
        title: String,
        startDate: Date,
        duration: Int, // in minutes
        notes: String? = nil,
        calendar: EKCalendar? = nil
    ) -> Bool {
        guard hasAccess else { return false }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .minute, value: duration, to: startDate)
        event.notes = notes
        event.calendar = calendar ?? defaultCalendar

        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            print("Failed to save event: \(error)")
            return false
        }
    }

    func createTimeBlockForLoop(
        loop: OpenLoopModel,
        startDate: Date,
        duration: Int? = nil,
        calendar: EKCalendar? = nil
    ) -> Bool {
        let blockDuration = duration ?? loop.estimatedMinutes ?? 60
        let sphereName = loop.sphere?.name ?? "Spheres"

        return createTimeBlock(
            title: "[\(sphereName)] \(loop.content)",
            startDate: startDate,
            duration: blockDuration,
            notes: "Created from Spheres app\nPriority: \(loop.importance)\nProgress: \(Int(loop.progress * 100))%",
            calendar: calendar
        )
    }

    // MARK: - Delete Events
    func deleteEvent(_ event: EKEvent) -> Bool {
        do {
            try eventStore.remove(event, span: .thisEvent)
            return true
        } catch {
            print("Failed to delete event: \(error)")
            return false
        }
    }
}

// MARK: - Calendar Event Helper
struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: Color
    let ekEvent: EKEvent

    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.title = ekEvent.title ?? "Untitled"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendarColor = Color(cgColor: ekEvent.calendar.cgColor)
        self.ekEvent = ekEvent
    }
}

// MARK: - Time Slot Helper
struct TimeSlot: Identifiable {
    let id = UUID()
    let hour: Int
    let date: Date

    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}

// MARK: - Google Calendar Support
struct GoogleCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarId: String

    var calendarColor: Color { .blue }
}

extension CalendarService {
    // MARK: - Google Calendar API
    // Note: For full Google Calendar API, you need:
    // 1. Google Cloud Console project with Calendar API enabled
    // 2. OAuth 2.0 credentials (Client ID)
    // 3. Implement OAuth flow

    // For now, we use system calendars which can include Google Calendar
    // if the user has added their Google account to macOS Internet Accounts

    var googleCalendars: [EKCalendar] {
        calendars.filter { $0.source.sourceType == .calDAV && $0.source.title.lowercased().contains("google") }
    }

    var hasGoogleCalendarSync: Bool {
        !googleCalendars.isEmpty
    }

    // Filter events by calendar type
    func eventsFromGoogle() -> [EKEvent] {
        let googleCalendarIds = Set(googleCalendars.map { $0.calendarIdentifier })
        return events.filter { googleCalendarIds.contains($0.calendar.calendarIdentifier) }
    }

    func eventsFromApple() -> [EKEvent] {
        let googleCalendarIds = Set(googleCalendars.map { $0.calendarIdentifier })
        return events.filter { !googleCalendarIds.contains($0.calendar.calendarIdentifier) }
    }

    // Create event on specific calendar (Google or Apple)
    func createTimeBlockOnCalendar(
        title: String,
        startDate: Date,
        duration: Int,
        notes: String? = nil,
        calendarId: String? = nil,
        preferGoogle: Bool = false
    ) -> Bool {
        guard hasAccess else { return false }

        var targetCalendar: EKCalendar?

        if let id = calendarId {
            targetCalendar = calendars.first { $0.calendarIdentifier == id }
        } else if preferGoogle, let googleCal = googleCalendars.first {
            targetCalendar = googleCal
        } else {
            targetCalendar = defaultCalendar
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .minute, value: duration, to: startDate)
        event.notes = notes
        event.calendar = targetCalendar ?? defaultCalendar

        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            print("Failed to save event: \(error)")
            return false
        }
    }
}

// MARK: - Free Time Slot Detection
extension CalendarService {
    struct FreeSlot: Identifiable {
        let id = UUID()
        let startDate: Date
        let endDate: Date

        init(startDate: Date, endDate: Date) {
            self.startDate = startDate
            self.endDate = endDate
        }

        var duration: Int {
            Int(endDate.timeIntervalSince(startDate) / 60)
        }

        var displayTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: startDate)
        }

        var displayRange: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }

    struct WorkingHours {
        let startHour: Int
        let endHour: Int

        static let fallback = WorkingHours(startHour: 9, endHour: 18)
    }

    /// Analyze the user's past 2 weeks of calendar events to learn their typical working hours
    func analyzeWorkingHours() -> WorkingHours {
        guard hasAccess else { return WorkingHours.fallback }

        let calendar = Calendar.current
        let now = Date()

        // Look back 14 days
        guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) else {
            return WorkingHours.fallback
        }

        // Fetch events from past 2 weeks
        let predicate = eventStore.predicateForEvents(withStart: twoWeeksAgo, end: now, calendars: nil)
        let pastEvents = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay } // Only timed events

        guard pastEvents.count >= 5 else {
            // Not enough data, use defaults
            return WorkingHours.fallback
        }

        // Count events per hour
        var hourCounts: [Int: Int] = [:]
        for event in pastEvents {
            let startHour = calendar.component(.hour, from: event.startDate)
            let endHour = calendar.component(.hour, from: event.endDate)

            // Count each hour the event spans
            for hour in startHour..<max(endHour, startHour + 1) {
                hourCounts[hour, default: 0] += 1
            }
        }

        // Find the range of hours with significant activity (at least 10% of peak)
        let peakCount = hourCounts.values.max() ?? 1
        let threshold = max(peakCount / 10, 1)

        let activeHours = hourCounts.filter { $0.value >= threshold }.keys.sorted()

        guard let firstActive = activeHours.first, let lastActive = activeHours.last else {
            return WorkingHours.fallback
        }

        // Clamp to reasonable bounds (no earlier than 6am, no later than 11pm)
        let startHour = max(firstActive, 6)
        let endHour = min(lastActive + 1, 23) // +1 because we want end of that hour

        print("[WorkingHours] Analyzed \(pastEvents.count) events, detected working hours: \(startHour):00 - \(endHour):00")

        return WorkingHours(startHour: startHour, endHour: endHour)
    }

    /// Find free time slots for today that can fit a task of given duration
    /// Uses learned working hours from past calendar activity
    func findFreeSlots(forDuration minutes: Int, on date: Date = Date()) -> [FreeSlot] {
        let calendar = Calendar.current
        let now = Date()

        // Learn working hours from past calendar activity
        let workingHours = analyzeWorkingHours()

        var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
        startComponents.hour = workingHours.startHour
        startComponents.minute = 0
        let workStart = calendar.date(from: startComponents) ?? date

        var endComponents = startComponents
        endComponents.hour = workingHours.endHour
        let workEnd = calendar.date(from: endComponents) ?? date

        // If looking at today, start from now (rounded up to next 15 min)
        var searchStart = workStart
        if calendar.isDateInToday(date) && now > workStart {
            let minuteComponent = calendar.component(.minute, from: now)
            let roundedMinutes = ((minuteComponent / 15) + 1) * 15
            var adjustedHour = calendar.component(.hour, from: now)
            var adjustedMinute = roundedMinutes

            if roundedMinutes >= 60 {
                adjustedHour += 1
                adjustedMinute = 0
            }

            searchStart = calendar.date(bySettingHour: adjustedHour,
                                         minute: adjustedMinute,
                                         second: 0, of: date) ?? now
        }

        guard searchStart < workEnd else { return [] }

        // Fetch events for the day
        fetchEventsForDay(date)
        let dayEvents = events.filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }

        var freeSlots: [FreeSlot] = []
        var currentTime = searchStart

        for event in dayEvents {
            // If there's a gap before this event
            if event.startDate > currentTime {
                let gapEnd = min(event.startDate, workEnd)
                let gapMinutes = Int(gapEnd.timeIntervalSince(currentTime) / 60)

                if gapMinutes >= minutes {
                    let slotEnd = calendar.date(byAdding: .minute, value: minutes, to: currentTime) ?? currentTime
                    freeSlots.append(FreeSlot(startDate: currentTime, endDate: slotEnd))
                }
            }

            // Move current time past this event
            if event.endDate > currentTime {
                currentTime = event.endDate
            }
        }

        // Check for free time after last event
        if currentTime < workEnd {
            let remainingMinutes = Int(workEnd.timeIntervalSince(currentTime) / 60)
            if remainingMinutes >= minutes {
                let slotEnd = calendar.date(byAdding: .minute, value: minutes, to: currentTime) ?? currentTime
                freeSlots.append(FreeSlot(startDate: currentTime, endDate: slotEnd))
            }
        }

        return Array(freeSlots.prefix(3)) // Return top 3 slots
    }

    // MARK: - Smart Setup: Calendar Summarization

    /// Summarize recent calendar activity for AI analysis during Smart Setup
    /// Groups events by keyword patterns and returns a human-readable summary
    func summarizeRecentActivity(days: Int = 30) -> String {
        guard hasAccess else { return "Calendar access not granted." }

        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else { return "" }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: now, calendars: nil)
        let allEvents = eventStore.events(matching: predicate)

        guard !allEvents.isEmpty else { return "No calendar events in the last \(days) days." }

        // Group events by normalized title
        var categories: [String: (count: Int, titles: Set<String>, hours: Set<Int>, weekdays: Set<Int>)] = [:]

        for event in allEvents {
            let title = event.title ?? "Untitled"
            let normalized = normalizeEventTitle(title)
            let hour = calendar.component(.hour, from: event.startDate)
            let weekday = calendar.component(.weekday, from: event.startDate)

            var entry = categories[normalized] ?? (count: 0, titles: [], hours: [], weekdays: [])
            entry.count += 1
            entry.titles.insert(title)
            entry.hours.insert(hour)
            entry.weekdays.insert(weekday)
            categories[normalized] = entry
        }

        // Sort by frequency and build summary
        let sorted = categories.sorted { $0.value.count > $1.value.count }
        var lines: [String] = []
        lines.append("Total events in last \(days) days: \(allEvents.count)")

        for (category, data) in sorted.prefix(15) {
            let displayName = data.titles.first ?? category
            let timeRange = formatHourRange(data.hours)
            let dayPattern = formatWeekdayPattern(data.weekdays)
            let frequency = data.count >= days ? "\(data.count / (days / 7))/week" : "\(data.count) total"
            lines.append("- \(displayName) (\(frequency), \(dayPattern), \(timeRange))")
        }

        return lines.joined(separator: "\n")
    }

    private func normalizeEventTitle(_ title: String) -> String {
        // Strip common prefixes/suffixes and lowercase for grouping
        let lowered = title.lowercased()
            .replacingOccurrences(of: "weekly ", with: "")
            .replacingOccurrences(of: "daily ", with: "")
            .replacingOccurrences(of: "monthly ", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Group by first 3 significant words
        let words = lowered.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return words.prefix(3).joined(separator: " ")
    }

    private func formatHourRange(_ hours: Set<Int>) -> String {
        guard let minHour = hours.min(), let maxHour = hours.max() else { return "" }
        if minHour == maxHour {
            return "\(formatHour(minHour))"
        }
        return "\(formatHour(minHour))-\(formatHour(maxHour))"
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12am" }
        if hour < 12 { return "\(hour)am" }
        if hour == 12 { return "12pm" }
        return "\(hour - 12)pm"
    }

    private func formatWeekdayPattern(_ weekdays: Set<Int>) -> String {
        let allDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
        let weekdaySet: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri
        let weekendSet: Set<Int> = [1, 7] // Sun, Sat

        if weekdays.isSuperset(of: weekdaySet) && weekdays.isDisjoint(with: weekendSet) {
            return "Mon-Fri"
        }
        if weekdays == weekendSet { return "weekends" }
        if weekdays == allDays { return "daily" }

        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekdays.sorted().compactMap { $0 < dayNames.count ? dayNames[$0] : nil }.joined(separator: "/")
    }
}

// MARK: - Unified Calendar Event (works with both EKEvent and Google API)
struct UnifiedCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: Color
    let calendarName: String
    let isGoogleCalendar: Bool

    init(from ekEvent: EKEvent, googleCalendarIds: Set<String>) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.title = ekEvent.title ?? "Untitled"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendarColor = Color(cgColor: ekEvent.calendar.cgColor)
        self.calendarName = ekEvent.calendar.title
        self.isGoogleCalendar = googleCalendarIds.contains(ekEvent.calendar.calendarIdentifier)
    }
}
