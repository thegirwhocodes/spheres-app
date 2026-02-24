//
//  SmartScheduleView.swift
//  Spheres - Smart Life Manager
//
//  Drag-and-drop smart scheduling interface
//  Shows AI-suggested time blocks based on energy optimization
//

import SwiftUI
import SwiftData
import EventKit
import UniformTypeIdentifiers

// MARK: - Smart Schedule View
struct SmartScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<OpenLoopModel> { !$0.isCompleted }) private var openLoops: [OpenLoopModel]
    @StateObject private var energyService = EnergyIntelligenceService.shared
    @StateObject private var calendarService = CalendarService.shared

    @State private var suggestions: [SmartTimeBlockSuggestion] = []
    @State private var isLoading = false
    @State private var selectedDate = Date()
    @State private var showingEnergyOnboarding = false
    @State private var draggedSuggestion: SmartTimeBlockSuggestion?
    @State private var existingEvents: [EKEvent] = []
    @AppStorage("scheduledLoopIds") private var scheduledLoopIdsString = ""
    @AppStorage("skippedEnergyOnboarding") private var skippedEnergyOnboarding = false

    // Parse scheduled loop IDs
    private var scheduledLoopIds: Set<UUID> {
        Set(scheduledLoopIdsString.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    // Filter out already-scheduled loops
    private var unscheduledLoops: [OpenLoopModel] {
        openLoops.filter { !scheduledLoopIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with energy profile status
            headerView

            Divider()
                .background(SpheresTheme.border)

            // Main content
            if energyService.hasCompletedOnboarding || skippedEnergyOnboarding {
                schedulingContent
            } else {
                energyOnboardingPrompt
            }
        }
        .background(SpheresTheme.background)
        .sheet(isPresented: $showingEnergyOnboarding) {
            EnergyProfilingSheet(isPresented: $showingEnergyOnboarding)
        }
        .onAppear {
            loadExistingEvents()
            if energyService.hasCompletedOnboarding {
                refreshSuggestions()
            }
        }
        .onChange(of: selectedDate) { _, _ in
            loadExistingEvents()
            refreshSuggestions()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Schedule")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                if let profile = energyService.userEnergyProfile {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 10))
                        Text(profile.chronotype.displayName)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(SpheresTheme.accent)
                }
            }

            Spacer()

            // Date picker
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)

            // Refresh button
            Button(action: refreshSuggestions) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(SpheresTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            // Energy settings button
            Button(action: { showingEnergyOnboarding = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14))
                    .foregroundColor(SpheresTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Scheduling Content
    private var schedulingContent: some View {
        HStack(spacing: 0) {
            // Left: Calendar timeline view
            calendarTimelineView
                .frame(maxWidth: .infinity)

            Divider()
                .background(SpheresTheme.border)

            // Right: Suggested time blocks
            suggestionsPanel
                .frame(width: 320)
        }
    }

    // MARK: - Calendar Timeline
    private var calendarTimelineView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(8..<21) { hour in
                    TimelineHourRow(
                        hour: hour,
                        date: selectedDate,
                        events: existingEvents.filter { event in
                            let eventHour = Calendar.current.component(.hour, from: event.startDate)
                            return eventHour == hour
                        },
                        suggestions: suggestions.filter { suggestion in
                            let suggestionHour = Calendar.current.component(.hour, from: suggestion.suggestedStartTime)
                            return suggestionHour == hour
                        },
                        energyLevel: energyService.userEnergyProfile?.energyAt(hour: hour) ?? 0.5,
                        onDropSuggestion: { suggestion in
                            handleDrop(suggestion: suggestion, atHour: hour)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Suggestions Panel
    private var suggestionsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Suggested Time Blocks")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Energy indicator
            if let profile = energyService.userEnergyProfile {
                CurrentEnergyIndicator(profile: profile)
                    .padding(.horizontal, 16)
            }

            Divider()
                .padding(.horizontal, 16)

            // Suggestions list
            if suggestions.isEmpty && !isLoading {
                emptySuggestionsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(suggestions) { suggestion in
                            DraggableSuggestionCard(
                                suggestion: suggestion,
                                isDragging: draggedSuggestion?.id == suggestion.id,
                                onSchedule: { scheduleSuggestion(suggestion) }
                            )
                            .onDrag {
                                self.draggedSuggestion = suggestion
                                return NSItemProvider(object: suggestion.id.uuidString as NSString)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }

            Spacer()
        }
        .background(SpheresTheme.surface.opacity(0.5))
    }

    private var emptySuggestionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(SpheresTheme.textMuted)

            Text("No tasks to schedule")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(SpheresTheme.textSecondary)

            Text("Add open loops to your spheres to get smart scheduling suggestions")
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    // MARK: - Energy Onboarding Prompt
    private var energyOnboardingPrompt: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(SpheresTheme.accent.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Circle()
                        .fill(SpheresTheme.accent.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 36))
                        .foregroundColor(SpheresTheme.accent)
                }

                VStack(spacing: 12) {
                    Text("Unlock Smart Scheduling")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(SpheresTheme.textPrimary)

                    Text("Let Spheres learn your energy patterns to schedule tasks at optimal times.")
                        .font(.system(size: 15))
                        .foregroundColor(SpheresTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }

                Button(action: { showingEnergyOnboarding = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Set Up Energy Profile")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SpheresTheme.accent)
                    )
                }
                .buttonStyle(.plain)

                // Skip button
                Button(action: { skippedEnergyOnboarding = true }) {
                    Text("Skip for now")
                        .font(.system(size: 13))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                // Benefits
                HStack(spacing: 24) {
                    BenefitBadge(icon: "brain", text: "AI-powered")
                    BenefitBadge(icon: "clock.fill", text: "Optimal timing")
                    BenefitBadge(icon: "chart.line.uptrend.xyaxis", text: "Learn over time")
                }
                .padding(.top, 16)

                Spacer()
            }
            .padding(40)

            // X button to dismiss
            Button(action: { skippedEnergyOnboarding = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SpheresTheme.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(SpheresTheme.surface)
                    )
            }
            .buttonStyle(.plain)
            .padding(20)
        }
    }

    // MARK: - Actions

    private func loadExistingEvents() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        calendarService.fetchEvents(from: startOfDay, to: endOfDay)
        existingEvents = calendarService.events
    }

    private func refreshSuggestions() {
        isLoading = true
        Task {
            let newSuggestions = await energyService.generateSmartSuggestions(
                for: Array(unscheduledLoops),
                existingEvents: existingEvents,
                date: selectedDate
            )
            await MainActor.run {
                suggestions = newSuggestions
                isLoading = false
            }
        }
    }

    private func handleDrop(suggestion: SmartTimeBlockSuggestion, atHour hour: Int) {
        // Update suggestion with new time
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = hour
        components.minute = 0

        guard let newStartTime = calendar.date(from: components) else { return }

        // Schedule the task at the new time
        scheduleSuggestionAt(suggestion, startTime: newStartTime)
    }

    private func scheduleSuggestion(_ suggestion: SmartTimeBlockSuggestion) {
        scheduleSuggestionAt(suggestion, startTime: suggestion.suggestedStartTime)
    }

    private func scheduleSuggestionAt(_ suggestion: SmartTimeBlockSuggestion, startTime: Date) {
        // Create calendar event
        let success = calendarService.createTimeBlockOnCalendar(
            title: suggestion.loop.content,
            startDate: startTime,
            duration: suggestion.durationMinutes,
            notes: "Scheduled by Spheres - \(suggestion.category.displayName)"
        )

        if success {
            // Mark as scheduled
            markLoopAsScheduled(suggestion.loop.id)

            // Remove from suggestions
            withAnimation {
                suggestions.removeAll { $0.id == suggestion.id }
            }

            // Reload events
            loadExistingEvents()
        }
    }

    private func markLoopAsScheduled(_ loopId: UUID) {
        var ids = scheduledLoopIdsString.isEmpty ? [] : scheduledLoopIdsString.split(separator: ",").map(String.init)
        ids.append(loopId.uuidString)
        scheduledLoopIdsString = ids.joined(separator: ",")
    }
}

// MARK: - Timeline Hour Row
struct TimelineHourRow: View {
    let hour: Int
    let date: Date
    let events: [EKEvent]
    let suggestions: [SmartTimeBlockSuggestion]
    let energyLevel: Double
    let onDropSuggestion: (SmartTimeBlockSuggestion) -> Void

    @State private var isDropTarget = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time label
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatHour(hour))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                // Energy indicator dot
                Circle()
                    .fill(energyColor)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 50)

            // Energy bar (visual indicator)
            RoundedRectangle(cornerRadius: 2)
                .fill(energyColor.opacity(0.3))
                .frame(width: 4, height: 60)

            // Content area
            VStack(alignment: .leading, spacing: 4) {
                // Existing events
                ForEach(events, id: \.eventIdentifier) { event in
                    ExistingEventCard(event: event)
                }

                // Scheduled suggestions for this hour
                ForEach(suggestions) { suggestion in
                    ScheduledSuggestionCard(suggestion: suggestion)
                }

                // Empty drop zone
                if events.isEmpty && suggestions.isEmpty {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDropTarget ? SpheresTheme.accent.opacity(0.2) : SpheresTheme.surface.opacity(0.3))
                        .frame(height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    isDropTarget ? SpheresTheme.accent : Color.clear,
                                    style: StrokeStyle(lineWidth: 2, dash: [5])
                                )
                        )
                        .overlay(
                            Text(isDropTarget ? "Drop here" : "")
                                .font(.system(size: 12))
                                .foregroundColor(SpheresTheme.accent)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .onDrop(of: [.text], isTargeted: $isDropTarget) { providers in
            // Handle drop
            return true
        }
    }

    private var energyColor: Color {
        if energyLevel > 0.7 {
            return .green
        } else if energyLevel > 0.4 {
            return .yellow
        } else {
            return .orange
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

// MARK: - Existing Event Card
struct ExistingEventCard: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(1)

                Text(formatTimeRange(event.startDate, event.endDate))
                    .font(.system(size: 11))
                    .foregroundColor(SpheresTheme.textTertiary)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SpheresTheme.surface)
        )
    }

    private func formatTimeRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Scheduled Suggestion Card
struct ScheduledSuggestionCard: View {
    let suggestion: SmartTimeBlockSuggestion

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(suggestion.category.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.loop.content)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: suggestion.category.icon)
                        .font(.system(size: 10))

                    Text(suggestion.category.displayName)
                        .font(.system(size: 11))
                }
                .foregroundColor(suggestion.category.color)
            }

            Spacer()

            // Energy indicator
            EnergyBadge(level: suggestion.energyLevel)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(suggestion.category.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(suggestion.category.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Draggable Suggestion Card
struct DraggableSuggestionCard: View {
    let suggestion: SmartTimeBlockSuggestion
    let isDragging: Bool
    let onSchedule: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: suggestion.category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(suggestion.category.color)

                Text(suggestion.loop.content)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(2)

                Spacer()

                // Confidence indicator
                ConfidenceBadge(confidence: suggestion.confidence)
            }

            // Suggested time
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(formatTime(suggestion.suggestedStartTime))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(SpheresTheme.textSecondary)

                Text("\(suggestion.durationMinutes) min")
                    .font(.system(size: 11))
                    .foregroundColor(SpheresTheme.textTertiary)

                Spacer()

                EnergyBadge(level: suggestion.energyLevel)
            }

            // Reason
            Text(suggestion.reason)
                .font(.system(size: 11))
                .foregroundColor(SpheresTheme.textTertiary)
                .lineLimit(2)

            // Actions
            HStack(spacing: 8) {
                Button(action: onSchedule) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus")
                        Text("Schedule")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(suggestion.category.color)
                    )
                }
                .buttonStyle(.plain)

                // Drag hint
                HStack(spacing: 4) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 10))
                    Text("Drag to reschedule")
                        .font(.system(size: 10))
                }
                .foregroundColor(SpheresTheme.textMuted)

                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SpheresTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isDragging ? suggestion.category.color : (isHovering ? SpheresTheme.border : Color.clear),
                            lineWidth: isDragging ? 2 : 1
                        )
                )
        )
        .opacity(isDragging ? 0.5 : 1)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct CurrentEnergyIndicator: View {
    let profile: EnergyProfile

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    private var currentEnergy: Double {
        profile.energyAt(hour: currentHour)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Energy level bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SpheresTheme.surface)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(energyGradient)
                        .frame(width: geometry.size.width * currentEnergy)
                }
            }
            .frame(height: 8)

            // Label
            Text("\(Int(currentEnergy * 100))% energy")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(energyColor)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SpheresTheme.background)
        )
    }

    private var energyColor: Color {
        if currentEnergy > 0.7 {
            return .green
        } else if currentEnergy > 0.4 {
            return .yellow
        } else {
            return .orange
        }
    }

    private var energyGradient: LinearGradient {
        LinearGradient(
            colors: [energyColor.opacity(0.7), energyColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct EnergyBadge: View {
    let level: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 8))

            Text("\(Int(level * 100))%")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.15))
        )
    }

    private var badgeColor: Color {
        if level > 0.7 {
            return .green
        } else if level > 0.4 {
            return .yellow
        } else {
            return .orange
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index < confidenceLevel ? SpheresTheme.accent : SpheresTheme.textMuted)
                    .frame(width: 4, height: 4)
            }
        }
    }

    private var confidenceLevel: Int {
        if confidence > 0.7 {
            return 3
        } else if confidence > 0.4 {
            return 2
        } else {
            return 1
        }
    }
}

struct BenefitBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.accent)

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(SpheresTheme.surface)
        )
    }
}

// MARK: - Energy Profile Settings Section (for Settings view)
struct EnergyProfileSettingsSection: View {
    @StateObject private var energyService = EnergyIntelligenceService.shared
    @State private var showingEnergyOnboarding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ENERGY INTELLIGENCE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(SpheresTheme.textTertiary)
                .tracking(1)

            VStack(alignment: .leading, spacing: 16) {
                // Status
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(energyService.hasCompletedOnboarding ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: energyService.hasCompletedOnboarding ? "waveform.path.ecg" : "waveform.path.ecg.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(energyService.hasCompletedOnboarding ? .green : .orange)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Energy Profile")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)

                        if energyService.hasCompletedOnboarding {
                            if let profile = energyService.userEnergyProfile {
                                Text("\(profile.chronotype.displayName) • Updated \(profile.lastUpdated.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.system(size: 12))
                                    .foregroundColor(SpheresTheme.textSecondary)
                            }
                        } else {
                            Text("Not configured — set up to unlock smart scheduling")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }

                    Spacer()
                }

                if energyService.hasCompletedOnboarding, let profile = energyService.userEnergyProfile {
                    Divider().background(SpheresTheme.border)

                    // Quick stats
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("Chronotype")
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.textTertiary)
                            Text(profile.chronotype.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(SpheresTheme.textPrimary)
                        }

                        VStack(spacing: 4) {
                            Text("Peak Hours")
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.textTertiary)
                            Text(formatHourRange(profile.chronotype.peakHours))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.green)
                        }

                        VStack(spacing: 4) {
                            Text("Work Hours")
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.textTertiary)
                            Text(formatHourRange(profile.preferredWorkHours))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(SpheresTheme.textPrimary)
                        }

                        VStack(spacing: 4) {
                            Text("Exercise")
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.textTertiary)
                            Text(profile.preferredExerciseTime.displayName.components(separatedBy: " ").first ?? "")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(SpheresTheme.textPrimary)
                        }

                        Spacer()
                    }

                    Divider().background(SpheresTheme.border)
                }

                // Action button
                Button(action: { showingEnergyOnboarding = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: energyService.hasCompletedOnboarding ? "pencil" : "sparkles")
                        Text(energyService.hasCompletedOnboarding ? "Update Energy Profile" : "Set Up Energy Profile")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(energyService.hasCompletedOnboarding ? SpheresTheme.accent : Color.orange)
                    )
                }
                .buttonStyle(.plain)

                // Description
                Text("Energy Intelligence uses neuroscience research to schedule tasks at optimal times based on your circadian rhythm and chronotype.")
                    .font(.system(size: 11))
                    .foregroundColor(SpheresTheme.textTertiary)
                    .lineSpacing(2)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
        }
        .sheet(isPresented: $showingEnergyOnboarding) {
            EnergyProfilingSheet(isPresented: $showingEnergyOnboarding)
        }
    }

    private func formatHourRange(_ range: ClosedRange<Int>) -> String {
        let startHour = range.lowerBound
        let endHour = range.upperBound
        let startPeriod = startHour >= 12 ? "PM" : "AM"
        let endPeriod = endHour >= 12 ? "PM" : "AM"
        let startDisplay = startHour > 12 ? startHour - 12 : (startHour == 0 ? 12 : startHour)
        let endDisplay = endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour)
        return "\(startDisplay)\(startPeriod)-\(endDisplay)\(endPeriod)"
    }
}

// MARK: - Preview
#Preview {
    SmartScheduleView()
        .frame(width: 900, height: 600)
}
