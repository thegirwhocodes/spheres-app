//
//  ScheduleView.swift
//  Spheres - Smart Life Manager
//
//  Schedule view with calendar, time blocking, and AI suggestions.
//

import SwiftUI
import SwiftData
import EventKit

// MARK: - Schedule View
struct ScheduleView: View {
    var body: some View {
        SmartScheduleView()
    }
}

// MARK: - Legacy Schedule View (kept for reference)
struct LegacyScheduleView: View {
    @Query(sort: \OpenLoopModel.createdDate) private var allLoops: [OpenLoopModel]
    @Query(sort: \SphereModel.priorityRank) private var spheres: [SphereModel]
    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var aiService = AIService.shared
    @State private var selectedDate = Date()
    @State private var showingTimeBlockSheet = false
    @State private var selectedLoopForBlocking: OpenLoopModel?
    @State private var scheduleSuggestions: [ScheduleSuggestion] = []
    @State private var isLoadingSuggestions = false

    @AppStorage("scheduledLoopIds") private var scheduledLoopIdsString: String = ""

    private var scheduledLoopIds: Set<String> {
        Set(scheduledLoopIdsString.components(separatedBy: ",").filter { !$0.isEmpty })
    }

    private func markLoopAsScheduled(_ loop: OpenLoopModel) {
        var ids = scheduledLoopIds
        ids.insert(loop.id.uuidString)
        scheduledLoopIdsString = ids.joined(separator: ",")
    }

    private var calendar: Calendar { Calendar.current }

    private var todaysLoops: [OpenLoopModel] {
        let scheduled = scheduledLoopIds
        return allLoops.filter { loop in
            guard !loop.isCompleted else { return false }
            guard !scheduled.contains(loop.id.uuidString) else { return false }
            if let due = loop.dueDate, calendar.isDate(due, inSameDayAs: selectedDate) {
                return true
            }
            return loop.importance <= 2
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(SpheresTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text(selectedDate.formatted(date: .complete, time: .omitted))
                            .font(.system(size: 14))
                            .foregroundColor(SpheresTheme.textSecondary)

                        if calendarService.hasGoogleCalendarSync {
                            HStack(spacing: 4) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 10))
                                Text("Google synced")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: { moveDate(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)

                    Button("Today") {
                        selectedDate = Date()
                    }
                    .buttonStyle(GhostButtonStyle())

                    Button(action: { moveDate(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
            .padding(.bottom, 0)

            if !calendarService.hasAccess {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(SpheresTheme.textTertiary)

                    Text("Calendar access required")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(SpheresTheme.textPrimary)

                    Text("Grant access to see your calendar events and create time blocks for your loops.")
                        .font(.system(size: 13))
                        .foregroundColor(SpheresTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)

                    Button("Grant Calendar Access") {
                        Task {
                            await calendarService.requestAccess()
                        }
                    }
                    .buttonStyle(AccentButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                TimelineRow(
                                    hour: hour,
                                    date: selectedDate,
                                    events: eventsForHour(hour),
                                    calendarService: calendarService
                                )
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 16) {
                        if !scheduleSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10))
                                        .foregroundColor(SpheresTheme.accent)
                                    Text("SUGGESTED TIME BLOCKS")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(SpheresTheme.textTertiary)
                                        .tracking(1)
                                }

                                ForEach(scheduleSuggestions) { suggestion in
                                    AISuggestionCard(
                                        suggestion: suggestion,
                                        onSchedule: {
                                            selectedLoopForBlocking = suggestion.loop
                                            showingTimeBlockSheet = true
                                        }
                                    )
                                }
                            }

                            Divider()
                                .background(SpheresTheme.textTertiary.opacity(0.3))
                                .padding(.vertical, 4)
                        } else if isLoadingSuggestions {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Getting suggestions...")
                                    .font(.system(size: 11))
                                    .foregroundColor(SpheresTheme.textTertiary)
                            }
                            .padding(.bottom, 8)
                        }

                        Text("LOOPS TO SCHEDULE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .tracking(1)

                        if todaysLoops.isEmpty {
                            Text("No urgent loops for today")
                                .font(.system(size: 12))
                                .foregroundColor(SpheresTheme.textTertiary)
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(todaysLoops) { loop in
                                        ScheduleLoopCard(
                                            loop: loop,
                                            onSchedule: {
                                                selectedLoopForBlocking = loop
                                                showingTimeBlockSheet = true
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(20)
                    .frame(width: 280)
                    .background(SpheresTheme.surface)
                }
            }
        }
        .onAppear {
            calendarService.fetchEventsForDay(selectedDate)
            fetchScheduleSuggestions()
        }
        .onChange(of: selectedDate) { _, newDate in
            calendarService.fetchEventsForDay(newDate)
            fetchScheduleSuggestions()
        }
        .sheet(isPresented: $showingTimeBlockSheet) {
            if let loop = selectedLoopForBlocking {
                TimeBlockSheet(
                    isPresented: $showingTimeBlockSheet,
                    loop: loop,
                    selectedDate: selectedDate,
                    calendarService: calendarService,
                    onScheduled: { markLoopAsScheduled(loop) }
                )
            }
        }
    }

    private func moveDate(by days: Int) {
        if let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func eventsForHour(_ hour: Int) -> [EKEvent] {
        calendarService.events.filter { event in
            let eventHour = calendar.component(.hour, from: event.startDate)
            return eventHour == hour
        }
    }

    private func fetchScheduleSuggestions() {
        isLoadingSuggestions = true
        scheduleSuggestions = []

        let existingEventSummary = calendarService.events.map { event in
            let time = event.startDate.formatted(date: .omitted, time: .shortened)
            let end = event.endDate.formatted(date: .omitted, time: .shortened)
            return "- \(event.title ?? "Untitled") (\(time) - \(end))"
        }

        let scheduled = scheduledLoopIds
        let unscheduledLoops = allLoops.filter { !scheduled.contains($0.id.uuidString) }

        Task {
            let suggestions = await aiService.getSchedulingSuggestions(
                loops: unscheduledLoops,
                existingEvents: existingEventSummary
            )
            await MainActor.run {
                scheduleSuggestions = suggestions
                isLoadingSuggestions = false
            }
        }
    }
}

// AI Suggestion Card for schedule
struct AISuggestionCard: View {
    let suggestion: ScheduleSuggestion
    let onSchedule: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(suggestion.loop.sphere?.color ?? SpheresTheme.accent)
                    .frame(width: 8, height: 8)

                Text(suggestion.loop.content)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(2)

                Spacer()
            }

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(suggestion.suggestedTime)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(SpheresTheme.accent)

                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9))
                    Text("\(suggestion.suggestedDuration)m")
                        .font(.system(size: 10))
                }
                .foregroundColor(SpheresTheme.textTertiary)

                Spacer()

                if isHovered {
                    Button(action: onSchedule) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 10))
                            Text("Schedule")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(TinyIconButtonStyle())
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                Text(suggestion.reason)
                    .font(.system(size: 10))
            }
            .foregroundColor(SpheresTheme.textTertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(SpheresTheme.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .onHover { isHovered = $0 }
    }
}

// Timeline row for each hour
struct TimelineRow: View {
    let hour: Int
    let date: Date
    let events: [EKEvent]
    let calendarService: CalendarService

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        let hourDate = Calendar.current.date(from: components) ?? date
        return formatter.string(from: hourDate)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(timeString)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(SpheresTheme.textTertiary)
                .frame(width: 50, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(SpheresTheme.border)
                    .frame(height: 1)

                if events.isEmpty {
                    Color.clear
                        .frame(height: 50)
                } else {
                    ForEach(events, id: \.eventIdentifier) { event in
                        CalendarEventCard(event: event, calendarService: calendarService)
                    }
                }
            }
        }
        .frame(minHeight: 60)
    }
}

// Calendar event card
struct CalendarEventCard: View {
    let event: EKEvent
    let calendarService: CalendarService
    @State private var isHovered = false
    @State private var showingEditSheet = false

    private var duration: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: event.startDate, to: event.endDate) ?? ""
    }

    var body: some View {
        Button(action: { showingEditSheet = true }) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color(cgColor: event.calendar.cgColor))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title ?? "Untitled")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(event.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10))
                        Text("•")
                        Text(duration)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(SpheresTheme.textTertiary)
                }

                Spacer()

                if isHovered {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(SpheresTheme.textSecondary)
                }

                if calendarService.googleCalendars.contains(where: { $0.calendarIdentifier == event.calendar.calendarIdentifier }) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .sheet(isPresented: $showingEditSheet) {
            EditCalendarEventSheet(
                isPresented: $showingEditSheet,
                event: event,
                calendarService: calendarService
            )
        }
    }
}

// Edit Calendar Event Sheet
struct EditCalendarEventSheet: View {
    @Binding var isPresented: Bool
    let event: EKEvent
    let calendarService: CalendarService
    @State private var title: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var selectedCalendar: EKCalendar?
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Event")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .padding(6)
                        .background(Circle().fill(SpheresTheme.surface))
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider().background(SpheresTheme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(SpheresTheme.textTertiary)

                        TextField("Event title", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.surface))
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Start")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(SpheresTheme.textTertiary)

                            DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("End")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(SpheresTheme.textTertiary)

                            DatePicker("", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(SpheresTheme.textTertiary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(calendarService.calendars, id: \.calendarIdentifier) { cal in
                                    Button(action: { selectedCalendar = cal }) {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color(cgColor: cal.cgColor))
                                                .frame(width: 8, height: 8)
                                            Text(cal.title)
                                                .font(.system(size: 12))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(selectedCalendar?.calendarIdentifier == cal.calendarIdentifier ? SpheresTheme.accent.opacity(0.2) : SpheresTheme.surface)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(selectedCalendar?.calendarIdentifier == cal.calendarIdentifier ? SpheresTheme.accent : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(SpheresTheme.textPrimary)
                                }
                            }
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }

            Divider().background(SpheresTheme.border)

            HStack(spacing: 12) {
                Button(action: { showDeleteConfirm = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                        Text("Delete")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))

                Spacer()

                Button(action: { isPresented = false }) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Button(action: saveChanges) {
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.accent))
            }
            .padding(20)
        }
        .frame(width: 420, height: 480)
        .background(SpheresTheme.background)
        .onAppear {
            title = event.title ?? ""
            startTime = event.startDate
            endTime = event.endDate
            selectedCalendar = event.calendar
        }
        .alert("Delete Event", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteEvent() }
        } message: {
            Text("Are you sure you want to delete this event? This cannot be undone.")
        }
    }

    private func saveChanges() {
        event.title = title
        event.startDate = startTime
        event.endDate = endTime
        if let newCal = selectedCalendar {
            event.calendar = newCal
        }

        do {
            try calendarService.eventStore.save(event, span: .thisEvent)
            calendarService.fetchEventsForDay(startTime)
            isPresented = false
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func deleteEvent() {
        _ = calendarService.deleteEvent(event)
        calendarService.fetchEventsForDay(event.startDate)
        isPresented = false
    }
}

// Loop card in schedule sidebar
struct ScheduleLoopCard: View {
    let loop: OpenLoopModel
    let onSchedule: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(loop.sphere?.color ?? SpheresTheme.accent)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(loop.content)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let mins = loop.estimatedMinutes {
                        Text("\(mins)m")
                            .font(.system(size: 10))
                    }
                    if let due = loop.dueDate {
                        Text("Due: \(due.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 10))
                    }
                }
                .foregroundColor(SpheresTheme.textTertiary)
            }

            Spacer()

            if isHovered {
                Button(action: onSchedule) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(TinyIconButtonStyle())
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
        )
        .onHover { isHovered = $0 }
    }
}

// Time block creation sheet
struct TimeBlockSheet: View {
    @Binding var isPresented: Bool
    let loop: OpenLoopModel
    let selectedDate: Date
    let calendarService: CalendarService
    var onScheduled: (() -> Void)? = nil

    @State private var startTime = Date()
    @State private var duration: Int = 60
    @State private var selectedCalendarId: String?
    @State private var preferGoogle = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Schedule Time Block")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Circle()
                    .fill(loop.sphere?.color ?? SpheresTheme.accent)
                    .frame(width: 12, height: 12)

                Text(loop.content)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(SpheresTheme.background)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Start Time")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                HStack(spacing: 10) {
                    ForEach([15, 30, 60, 90, 120], id: \.self) { mins in
                        Button(action: { duration = mins }) {
                            Text("\(mins)m")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(duration == mins ? .white : SpheresTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(duration == mins ? (loop.sphere?.color ?? SpheresTheme.accent) : SpheresTheme.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if calendarService.hasGoogleCalendarSync {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)

                    Toggle(isOn: $preferGoogle) {
                        HStack(spacing: 6) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 14))
                            Text("Add to Google Calendar")
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.switch)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(GhostButtonStyle())

                Spacer()

                Button("Create Time Block") {
                    createTimeBlock()
                    isPresented = false
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 400, height: 420)
        .background(SpheresTheme.surface)
        .onAppear {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: selectedDate)
            components.hour = (components.hour ?? 9) + 1
            components.minute = 0
            startTime = calendar.date(from: components) ?? selectedDate

            if let mins = loop.estimatedMinutes {
                duration = mins
            }
        }
    }

    private func createTimeBlock() {
        let success = calendarService.createTimeBlockOnCalendar(
            title: "[\(loop.sphere?.name ?? "Spheres")] \(loop.content)",
            startDate: startTime,
            duration: duration,
            notes: "Created from Spheres app\nPriority: \(loop.importance)",
            preferGoogle: preferGoogle
        )
        calendarService.fetchEventsForDay(selectedDate)
        if success {
            onScheduled?()
        }
    }
}

// MARK: - Proactive AI Scheduling Popup
struct ProactiveSchedulingPopup: View {
    @Binding var isPresented: Bool
    let loop: OpenLoopModel
    let suggestedSlot: CalendarService.FreeSlot
    let reason: String
    var onScheduled: (() -> Void)? = nil
    var onSeeDay: (() -> Void)? = nil
    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var aiService = AIService.shared
    @State private var isScheduling = false
    @State private var showSuccess = false
    @State private var showCalendarPreview = false
    @State private var errorMessage: String?
    @State private var showCustomTimeInput = false
    @State private var customTimeRequest = ""
    @State private var aiMessage = ""
    @State private var isLoadingAI = true
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    if !showCustomTimeInput { isPresented = false }
                }

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)

                        Image(systemName: "sparkles")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spheres Assistant")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)
                        Text("Just now")
                            .font(.system(size: 11))
                            .foregroundColor(SpheresTheme.textTertiary)
                    }

                    Spacer()

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .padding(8)
                            .background(Circle().fill(SpheresTheme.background))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)

                VStack(alignment: .leading, spacing: 16) {
                    if isLoadingAI {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .font(.system(size: 13))
                                .foregroundColor(SpheresTheme.textSecondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text(aiMessage)
                            .font(.system(size: 14))
                            .foregroundColor(SpheresTheme.textPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 0) {
                        HStack {
                            Text(suggestedSlot.startDate.formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(SpheresTheme.textPrimary)
                            Spacer()
                            Button(action: {
                                if let onSeeDay = onSeeDay {
                                    onSeeDay()
                                } else {
                                    showCalendarPreview.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("See day")
                                        .font(.system(size: 11))
                                    Image(systemName: "calendar")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(SpheresTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(SpheresTheme.surfaceHover)

                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(loop.sphere?.color ?? SpheresTheme.accent)
                                .frame(width: 4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(loop.content)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(SpheresTheme.textPrimary)
                                    .lineLimit(1)
                                Text(suggestedSlot.displayRange)
                                    .font(.system(size: 11))
                                    .foregroundColor(SpheresTheme.textSecondary)
                            }
                            .padding(.leading, 10)
                            .padding(.vertical, 10)

                            Spacer()

                            if let sphere = loop.sphere {
                                Text(sphere.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(sphere.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(sphere.color.opacity(0.15))
                                    .cornerRadius(4)
                                    .padding(.trailing, 10)
                            }
                        }
                        .background(SpheresTheme.background)

                        if showCalendarPreview {
                            MiniCalendarPreview(date: suggestedSlot.startDate, calendarService: calendarService)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 10).fill(SpheresTheme.background))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(loop.sphere?.color.opacity(0.3) ?? SpheresTheme.accent.opacity(0.3), lineWidth: 1)
                    )

                    if showCustomTimeInput {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("When works better for you?")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(SpheresTheme.textSecondary)

                            HStack(spacing: 8) {
                                TextField("e.g., tomorrow at 2pm, Friday morning...", text: $customTimeRequest)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.background))
                                    .focused($isInputFocused)

                                Button(action: processCustomTime) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(SpheresTheme.accent)
                                }
                                .buttonStyle(.plain)
                                .disabled(customTimeRequest.isEmpty)
                            }
                        }
                        .padding(.top, 4)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                Divider().background(SpheresTheme.border)

                HStack(spacing: 10) {
                    Button(action: scheduleIt) {
                        HStack(spacing: 4) {
                            if isScheduling {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.white)
                            } else if showSuccess {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                            } else {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 11))
                            }
                            Text(showSuccess ? "Done!" : "Yes")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(RoundedRectangle(cornerRadius: 8).fill(
                        showSuccess ? Color.green : (loop.sphere?.color ?? SpheresTheme.accent)
                    ))
                    .disabled(isScheduling || showSuccess)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCustomTimeInput.toggle()
                            if showCustomTimeInput {
                                isInputFocused = true
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text("Different time")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(SpheresTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.surfaceHover))

                    Button(action: { isPresented = false }) {
                        Text("Not now")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SpheresTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.surfaceHover))
                }
                .padding(20)
            }
            .frame(width: 460)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.08, green: 0.08, blue: 0.10)))
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
        }
        .onAppear {
            if !calendarService.hasAccess {
                Task {
                    _ = await calendarService.requestAccess()
                }
            }
            generateAIMessage()
        }
    }

    private func generateAIMessage() {
        Task {
            let message = await aiService.generateSchedulingSuggestion(
                loop: loop,
                suggestedTime: suggestedSlot.startDate,
                duration: suggestedSlot.duration
            )
            await MainActor.run {
                aiMessage = message
                isLoadingAI = false
            }
        }
    }

    private func processCustomTime() {
        isPresented = false
    }

    private func scheduleIt() {
        isScheduling = true
        errorMessage = nil

        guard calendarService.hasAccess else {
            Task {
                let granted = await calendarService.requestAccess()
                await MainActor.run {
                    isScheduling = false
                    if granted {
                        scheduleIt()
                    } else {
                        errorMessage = "Calendar access required. Please grant access in System Settings."
                    }
                }
            }
            return
        }

        let duration = loop.estimatedMinutes ?? suggestedSlot.duration
        let success = calendarService.createTimeBlockForLoop(
            loop: loop,
            startDate: suggestedSlot.startDate,
            duration: duration
        )

        isScheduling = false
        if success {
            showSuccess = true
            onScheduled?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isPresented = false
            }
        } else {
            errorMessage = "Couldn't create calendar event. Please check calendar permissions."
        }
    }
}

// Mini calendar preview showing surrounding events
struct MiniCalendarPreview: View {
    let date: Date
    let calendarService: CalendarService

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(SpheresTheme.border)

            if calendarService.events.isEmpty {
                Text("No other events this day")
                    .font(.system(size: 11))
                    .foregroundColor(SpheresTheme.textTertiary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 1) {
                    ForEach(calendarService.events.prefix(3), id: \.eventIdentifier) { event in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(cgColor: event.calendar.cgColor))
                                .frame(width: 6, height: 6)
                            Text(event.title ?? "Untitled")
                                .font(.system(size: 11))
                                .foregroundColor(SpheresTheme.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text(event.startDate.formatted(.dateTime.hour().minute()))
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.textTertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }

                    if calendarService.events.count > 3 {
                        Text("+ \(calendarService.events.count - 3) more")
                            .font(.system(size: 10))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .onAppear {
            calendarService.fetchEventsForDay(date)
        }
    }
}

#Preview("Schedule View") {
    ScheduleView()
        .modelContainer(previewContainer)
        .frame(width: 900, height: 600)
}
