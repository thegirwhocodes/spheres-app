//
//  EnergyIntelligence.swift
//  Spheres - Smart Life Manager
//
//  Energy-based intelligent scheduling system
//  Analyzes circadian rhythms, ultradian cycles, and personal energy patterns
//  to optimize task scheduling for peak performance.
//
//  Research basis:
//  - Circadian rhythms: 24-hour biological cycles affecting alertness, body temp, hormones
//  - Ultradian rhythms: 90-120 minute focus/rest cycles (Kleitman, 1950s)
//  - Chronotypes: Morning larks (15%), Third birds (65%), Night owls (20%)
//  - Decision fatigue: Quality deteriorates after extended decision-making
//  - Cognitive load theory: Tasks vary in mental energy requirements
//

import SwiftUI
import SwiftData
import EventKit

// MARK: - Energy Intelligence Service
@MainActor
class EnergyIntelligenceService: ObservableObject {
    static let shared = EnergyIntelligenceService()

    // MARK: - Published State
    @Published var userEnergyProfile: EnergyProfile?
    @Published var suggestedTimeBlocks: [SmartTimeBlockSuggestion] = []
    @Published var isAnalyzingCalendar = false
    @Published var analysisProgress: Double = 0.0
    @Published var hasCompletedOnboarding = false

    // Calendar access
    private let eventStore = EKEventStore()

    // AI Service for pattern analysis
    private let aiService = AIService.shared

    init() {
        loadSavedProfile()
    }

    // MARK: - Profile Management

    private func loadSavedProfile() {
        if let data = UserDefaults.standard.data(forKey: "userEnergyProfile"),
           let profile = try? JSONDecoder().decode(EnergyProfile.self, from: data) {
            self.userEnergyProfile = profile
            self.hasCompletedOnboarding = true
        }
    }

    func saveProfile(_ profile: EnergyProfile) {
        self.userEnergyProfile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "userEnergyProfile")
        }
        hasCompletedOnboarding = true
    }

    // MARK: - Calendar Analysis (Historical Data)

    /// Analyzes 1-3 years of calendar history to detect patterns
    func analyzeCalendarHistory(years: Int = 2) async -> CalendarAnalysisResult {
        isAnalyzingCalendar = true
        analysisProgress = 0.0

        defer { isAnalyzingCalendar = false }

        // Request calendar access
        guard await requestCalendarAccess() else {
            return CalendarAnalysisResult(patterns: [], insights: [], error: "Calendar access denied")
        }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .year, value: -years, to: endDate) else {
            return CalendarAnalysisResult(patterns: [], insights: [], error: "Invalid date range")
        }

        // Fetch all events
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        analysisProgress = 0.2

        // Categorize events by type and time
        var eventsByHour: [Int: [CategorizedEvent]] = [:]
        var eventsByDayOfWeek: [Int: [CategorizedEvent]] = [:]
        var taskCompletionPatterns: [TaskCompletionPattern] = []

        for (index, event) in events.enumerated() {
            let categorized = categorizeEvent(event)
            let hour = calendar.component(.hour, from: event.startDate)
            let dayOfWeek = calendar.component(.weekday, from: event.startDate)

            eventsByHour[hour, default: []].append(categorized)
            eventsByDayOfWeek[dayOfWeek, default: []].append(categorized)

            // Track completion patterns if event has notes indicating completion
            if let notes = event.notes, notes.lowercased().contains("completed") || notes.lowercased().contains("done") {
                taskCompletionPatterns.append(TaskCompletionPattern(
                    hour: hour,
                    dayOfWeek: dayOfWeek,
                    taskType: categorized.category,
                    duration: event.endDate.timeIntervalSince(event.startDate) / 60
                ))
            }

            // Update progress
            if index % 100 == 0 {
                analysisProgress = 0.2 + (0.5 * Double(index) / Double(events.count))
            }
        }

        analysisProgress = 0.7

        // Detect patterns
        let patterns = detectPatterns(
            eventsByHour: eventsByHour,
            eventsByDayOfWeek: eventsByDayOfWeek,
            completionPatterns: taskCompletionPatterns
        )

        analysisProgress = 0.9

        // Generate insights using AI
        let insights = await generateInsights(from: patterns, events: events)

        analysisProgress = 1.0

        return CalendarAnalysisResult(patterns: patterns, insights: insights, error: nil)
    }

    private func requestCalendarAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    private func categorizeEvent(_ event: EKEvent) -> CategorizedEvent {
        let title = event.title?.lowercased() ?? ""
        let category: TaskCategory

        // Categorize based on keywords
        if title.contains("meeting") || title.contains("call") || title.contains("sync") || title.contains("standup") {
            category = .meetings
        } else if title.contains("gym") || title.contains("workout") || title.contains("run") || title.contains("yoga") || title.contains("exercise") {
            category = .exercise
        } else if title.contains("email") || title.contains("inbox") || title.contains("respond") {
            category = .shallowWork
        } else if title.contains("focus") || title.contains("deep work") || title.contains("write") || title.contains("code") || title.contains("design") {
            category = .deepWork
        } else if title.contains("brainstorm") || title.contains("creative") || title.contains("ideate") {
            category = .creative
        } else if title.contains("lunch") || title.contains("break") || title.contains("rest") {
            category = .recovery
        } else if title.contains("plan") || title.contains("review") || title.contains("strategy") {
            category = .planning
        } else {
            category = .other
        }

        return CategorizedEvent(
            title: event.title ?? "Untitled",
            startDate: event.startDate,
            endDate: event.endDate,
            category: category
        )
    }

    private func detectPatterns(
        eventsByHour: [Int: [CategorizedEvent]],
        eventsByDayOfWeek: [Int: [CategorizedEvent]],
        completionPatterns: [TaskCompletionPattern]
    ) -> [DetectedPattern] {
        var patterns: [DetectedPattern] = []

        // Find peak hours for each task type
        var categoryByHour: [TaskCategory: [Int: Int]] = [:]

        for (hour, events) in eventsByHour {
            for event in events {
                categoryByHour[event.category, default: [:]][hour, default: 0] += 1
            }
        }

        for (category, hourCounts) in categoryByHour {
            // Find the hour with most events of this type
            if let (peakHour, count) = hourCounts.max(by: { $0.value < $1.value }), count >= 5 {
                patterns.append(DetectedPattern(
                    type: .peakActivityTime,
                    taskCategory: category,
                    hour: peakHour,
                    confidence: min(1.0, Double(count) / 50.0),
                    description: "You typically schedule \(category.displayName) around \(formatHour(peakHour))"
                ))
            }
        }

        // Detect meeting-heavy days
        for (day, events) in eventsByDayOfWeek {
            let meetingCount = events.filter { $0.category == .meetings }.count
            let totalDays = events.count / 52 // Approximate weeks in 2 years
            if totalDays > 0 && meetingCount / max(1, totalDays) > 3 {
                patterns.append(DetectedPattern(
                    type: .meetingHeavyDay,
                    taskCategory: .meetings,
                    dayOfWeek: day,
                    confidence: 0.8,
                    description: "\(dayName(day)) tends to be meeting-heavy"
                ))
            }
        }

        // Detect completion time patterns
        var completionsByHour: [Int: Int] = [:]
        for pattern in completionPatterns {
            completionsByHour[pattern.hour, default: 0] += 1
        }

        if let (peakHour, count) = completionsByHour.max(by: { $0.value < $1.value }), count >= 10 {
            patterns.append(DetectedPattern(
                type: .productivePeak,
                taskCategory: .deepWork,
                hour: peakHour,
                confidence: min(1.0, Double(count) / 100.0),
                description: "You complete most tasks around \(formatHour(peakHour))"
            ))
        }

        return patterns
    }

    private func generateInsights(from patterns: [DetectedPattern], events: [EKEvent]) async -> [EnergyInsight] {
        var insights: [EnergyInsight] = []

        // Insight 1: Best time for deep work
        if let deepWorkPattern = patterns.first(where: { $0.taskCategory == .deepWork && $0.type == .peakActivityTime }) {
            insights.append(EnergyInsight(
                title: "Your Deep Work Window",
                description: "Based on \(events.count) events, your most productive deep work time is around \(formatHour(deepWorkPattern.hour ?? 10)). This aligns with research showing late morning is optimal for 75% of people.",
                recommendation: "Protect \(formatHour(deepWorkPattern.hour ?? 10)) - \(formatHour((deepWorkPattern.hour ?? 10) + 2)) for your most important work.",
                icon: "brain.head.profile",
                priority: .high
            ))
        }

        // Insight 2: Exercise timing
        if let exercisePattern = patterns.first(where: { $0.taskCategory == .exercise }) {
            let hour = exercisePattern.hour ?? 7
            let isMorning = hour < 12
            insights.append(EnergyInsight(
                title: "Your Exercise Pattern",
                description: isMorning
                    ? "You prefer morning workouts. Research shows morning exercise improves sleep quality and accelerates fat loss."
                    : "You prefer afternoon/evening workouts. Research shows evening exercise optimizes muscle gain and peak performance.",
                recommendation: "Continue scheduling workouts around \(formatHour(hour)) - it matches your natural rhythm.",
                icon: "figure.run",
                priority: .medium
            ))
        }

        // Insight 3: Meeting load
        let meetingPatterns = patterns.filter { $0.type == .meetingHeavyDay }
        if !meetingPatterns.isEmpty {
            let days = meetingPatterns.compactMap { $0.dayOfWeek }.map { dayName($0) }.joined(separator: " and ")
            insights.append(EnergyInsight(
                title: "Meeting-Heavy Days",
                description: "\(days) have the most meetings. Decision fatigue research shows cognitive performance drops after extended meetings.",
                recommendation: "Schedule shallow work (emails, admin) after meeting blocks. Save deep work for meeting-light days.",
                icon: "person.3.fill",
                priority: .medium
            ))
        }

        // Insight 4: Recovery gaps
        let recoveryEvents = events.filter { categorizeEvent($0).category == .recovery }
        let avgRecoveryPerWeek = Double(recoveryEvents.count) / 104.0 // 2 years of weeks
        if avgRecoveryPerWeek < 3 {
            insights.append(EnergyInsight(
                title: "Recovery Deficit",
                description: "You schedule only \(String(format: "%.1f", avgRecoveryPerWeek)) recovery blocks per week. Ultradian rhythm research shows we need breaks every 90-120 minutes.",
                recommendation: "Add 20-minute recovery blocks after intense work sessions. Your brain needs this to consolidate learning.",
                icon: "moon.zzz.fill",
                priority: .high
            ))
        }

        return insights
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

    private func dayName(_ day: Int) -> String {
        let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[min(max(day, 1), 7)]
    }

    // MARK: - Smart Scheduling

    /// Generates values-aware intelligent time block suggestions
    /// Combines energy profile with user's core values for optimal scheduling
    func generateValuesAwareSuggestions(
        for loops: [OpenLoopModel],
        existingEvents: [EKEvent],
        date: Date = Date()
    ) async -> [SmartTimeBlockSuggestion] {
        let personalization = PersonalizationService.shared

        // Sort loops by value-weighted priority first
        let prioritizedLoops = personalization.sortByValuePriority(loops)

        // Generate suggestions with value context
        return await generateSmartSuggestions(
            for: prioritizedLoops,
            existingEvents: existingEvents,
            date: date,
            valueBoosts: prioritizedLoops.reduce(into: [:]) { dict, loop in
                if let sphere = loop.sphere {
                    dict[loop.id] = personalization.valueAlignmentBoost(for: sphere)
                }
            }
        )
    }

    /// Generates intelligent time block suggestions based on energy profile and task requirements
    func generateSmartSuggestions(
        for loops: [OpenLoopModel],
        existingEvents: [EKEvent],
        date: Date = Date(),
        valueBoosts: [UUID: Double] = [:]
    ) async -> [SmartTimeBlockSuggestion] {
        guard let profile = userEnergyProfile else {
            return generateDefaultSuggestions(for: loops, existingEvents: existingEvents, date: date)
        }

        var suggestions: [SmartTimeBlockSuggestion] = []
        let calendar = Calendar.current

        // Get available time slots for the day
        let availableSlots = findAvailableSlots(on: date, existingEvents: existingEvents)

        // Sort loops by importance and deadline
        let sortedLoops = loops.sorted { loop1, loop2 in
            // Priority 1: Due date (sooner = higher priority)
            if let due1 = loop1.dueDate, let due2 = loop2.dueDate {
                return due1 < due2
            } else if loop1.dueDate != nil {
                return true
            } else if loop2.dueDate != nil {
                return false
            }
            // Priority 2: Importance
            return loop1.importance < loop2.importance
        }

        for loop in sortedLoops {
            // Determine task category based on content
            let category = categorizeTask(loop)

            // Find optimal time based on energy profile and task type
            let optimalSlot = findOptimalSlot(
                for: category,
                profile: profile,
                availableSlots: availableSlots,
                duration: loop.estimatedMinutes ?? 30
            )

            if let slot = optimalSlot {
                let valueBoost = valueBoosts[loop.id] ?? 1.0
                let baseConfidence = calculateConfidence(slot: slot, category: category, profile: profile)
                let boostedConfidence = min(1.0, baseConfidence * (valueBoost > 1.0 ? 1.1 : 1.0))

                let suggestion = SmartTimeBlockSuggestion(
                    id: UUID(),
                    loop: loop,
                    suggestedStartTime: slot.start,
                    suggestedEndTime: slot.end,
                    energyLevel: profile.energyAt(hour: calendar.component(.hour, from: slot.start)),
                    category: category,
                    reason: generateReason(category: category, hour: calendar.component(.hour, from: slot.start), profile: profile, valueBoost: valueBoost, sphereName: loop.sphere?.name),
                    confidence: boostedConfidence,
                    alternativeTimes: findAlternativeSlots(for: category, profile: profile, availableSlots: availableSlots, excluding: slot),
                    isValueAligned: valueBoost > 1.0
                )
                suggestions.append(suggestion)
            }
        }

        return suggestions.sorted { $0.suggestedStartTime < $1.suggestedStartTime }
    }

    private func categorizeTask(_ loop: OpenLoopModel) -> TaskCategory {
        let content = loop.content.lowercased()

        if content.contains("email") || content.contains("respond") || content.contains("reply") || content.contains("inbox") {
            return .shallowWork
        } else if content.contains("gym") || content.contains("workout") || content.contains("run") || content.contains("exercise") {
            return .exercise
        } else if content.contains("write") || content.contains("code") || content.contains("design") || content.contains("analyze") || content.contains("research") {
            return .deepWork
        } else if content.contains("brainstorm") || content.contains("creative") || content.contains("ideate") || content.contains("sketch") {
            return .creative
        } else if content.contains("meet") || content.contains("call") || content.contains("sync") {
            return .meetings
        } else if content.contains("plan") || content.contains("review") || content.contains("strategy") {
            return .planning
        } else if loop.importance <= 2 {
            // High importance tasks default to deep work
            return .deepWork
        } else {
            return .shallowWork
        }
    }

    private func findAvailableSlots(on date: Date, existingEvents: [EKEvent]) -> [EnergyTimeSlot] {
        let calendar = Calendar.current
        var slots: [EnergyTimeSlot] = []

        // Define working hours (customizable based on profile)
        let workStart = 8
        let workEnd = 20

        // Create 30-minute slots
        for hour in workStart..<workEnd {
            for minute in [0, 30] {
                var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
                startComponents.hour = hour
                startComponents.minute = minute

                guard let slotStart = calendar.date(from: startComponents),
                      let slotEnd = calendar.date(byAdding: .minute, value: 30, to: slotStart) else {
                    continue
                }

                // Check if slot conflicts with existing events
                let hasConflict = existingEvents.contains { event in
                    slotStart < event.endDate && slotEnd > event.startDate
                }

                if !hasConflict {
                    slots.append(EnergyTimeSlot(start: slotStart, end: slotEnd))
                }
            }
        }

        return slots
    }

    private func findOptimalSlot(
        for category: TaskCategory,
        profile: EnergyProfile,
        availableSlots: [EnergyTimeSlot],
        duration: Int
    ) -> EnergyTimeSlot? {
        let calendar = Calendar.current
        let requiredSlots = max(1, duration / 30)

        // Find optimal hours based on task category and profile
        let optimalHours = profile.optimalHoursFor(category: category)

        // Try to find consecutive slots during optimal hours
        for startIndex in 0..<availableSlots.count {
            let startSlot = availableSlots[startIndex]
            let startHour = calendar.component(.hour, from: startSlot.start)

            // Check if this is an optimal hour
            guard optimalHours.contains(startHour) else { continue }

            // Check if we have enough consecutive slots
            if startIndex + requiredSlots <= availableSlots.count {
                var isConsecutive = true
                for i in 1..<requiredSlots {
                    let currentSlot = availableSlots[startIndex + i]
                    let previousSlot = availableSlots[startIndex + i - 1]
                    if currentSlot.start != previousSlot.end {
                        isConsecutive = false
                        break
                    }
                }

                if isConsecutive {
                    let endSlot = availableSlots[startIndex + requiredSlots - 1]
                    return EnergyTimeSlot(start: startSlot.start, end: endSlot.end)
                }
            }
        }

        // Fallback: return first available slot with enough time
        for startIndex in 0..<availableSlots.count {
            if startIndex + requiredSlots <= availableSlots.count {
                var isConsecutive = true
                for i in 1..<requiredSlots {
                    let currentSlot = availableSlots[startIndex + i]
                    let previousSlot = availableSlots[startIndex + i - 1]
                    if currentSlot.start != previousSlot.end {
                        isConsecutive = false
                        break
                    }
                }

                if isConsecutive {
                    let startSlot = availableSlots[startIndex]
                    let endSlot = availableSlots[startIndex + requiredSlots - 1]
                    return EnergyTimeSlot(start: startSlot.start, end: endSlot.end)
                }
            }
        }

        return availableSlots.first
    }

    private func findAlternativeSlots(
        for category: TaskCategory,
        profile: EnergyProfile,
        availableSlots: [EnergyTimeSlot],
        excluding: EnergyTimeSlot
    ) -> [EnergyTimeSlot] {
        let calendar = Calendar.current
        let optimalHours = profile.optimalHoursFor(category: category)

        return availableSlots
            .filter { $0.start != excluding.start }
            .filter { slot in
                let hour = calendar.component(.hour, from: slot.start)
                return optimalHours.contains(hour)
            }
            .prefix(3)
            .map { $0 }
    }

    private func generateReason(category: TaskCategory, hour: Int, profile: EnergyProfile, valueBoost: Double = 1.0, sphereName: String? = nil) -> String {
        let energyLevel = profile.energyAt(hour: hour)
        let energyDescription = energyLevel > 0.7 ? "peak energy" : energyLevel > 0.4 ? "moderate energy" : "recovery time"

        // Add value alignment context if applicable
        let valueContext: String
        if valueBoost > 1.0, let sphere = sphereName {
            valueContext = " This aligns with your core values in \(sphere)."
        } else {
            valueContext = ""
        }

        switch category {
        case .deepWork:
            return "Scheduled during your \(energyDescription) window when focus is highest.\(valueContext)"
        case .creative:
            if energyLevel < 0.6 {
                return "Creative work thrives during slight fatigue when you're more open to novel ideas.\(valueContext)"
            } else {
                return "Scheduled during your creative peak for optimal ideation.\(valueContext)"
            }
        case .shallowWork:
            return "Emails and admin work are ideal for post-lunch dips when deep focus is harder.\(valueContext)"
        case .exercise:
            if hour < 12 {
                return "Morning workouts boost metabolism and improve sleep quality.\(valueContext)"
            } else {
                return "Afternoon exercise optimizes performance and muscle building.\(valueContext)"
            }
        case .meetings:
            return "Meetings are scheduled when deep work isn't optimal.\(valueContext)"
        case .planning:
            return "Planning works well during high-energy morning hours.\(valueContext)"
        case .recovery:
            return "Recovery blocks restore your ultradian rhythm.\(valueContext)"
        case .other:
            return "Scheduled based on your available time.\(valueContext)"
        }
    }

    private func calculateConfidence(slot: EnergyTimeSlot, category: TaskCategory, profile: EnergyProfile) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: slot.start)
        let energyLevel = profile.energyAt(hour: hour)
        let optimalHours = profile.optimalHoursFor(category: category)

        var confidence = 0.5

        // Boost confidence if in optimal hours
        if optimalHours.contains(hour) {
            confidence += 0.3
        }

        // Adjust based on energy alignment
        switch category {
        case .deepWork, .planning:
            // These need high energy
            confidence += energyLevel * 0.2
        case .creative:
            // Creative work can benefit from slight fatigue
            if energyLevel > 0.3 && energyLevel < 0.7 {
                confidence += 0.2
            }
        case .shallowWork:
            // Works at any energy level
            confidence += 0.1
        case .exercise:
            // Depends on time preference
            confidence += 0.1
        default:
            break
        }

        return min(1.0, confidence)
    }

    private func generateDefaultSuggestions(
        for loops: [OpenLoopModel],
        existingEvents: [EKEvent],
        date: Date
    ) -> [SmartTimeBlockSuggestion] {
        // Default schedule based on research:
        // - 9-11 AM: Deep work (peak alertness for most)
        // - 11 AM-12 PM: Meetings/collaborative
        // - 12-1 PM: Lunch
        // - 1-3 PM: Shallow work (post-lunch dip)
        // - 3-5 PM: Creative work (openness increases)
        // - 5-7 PM: Exercise (peak body temp)

        let availableSlots = findAvailableSlots(on: date, existingEvents: existingEvents)
        var suggestions: [SmartTimeBlockSuggestion] = []
        let calendar = Calendar.current

        for loop in loops {
            let category = categorizeTask(loop)
            let duration = loop.estimatedMinutes ?? 30

            // Find slot based on default optimal times
            let optimalHours: [Int]
            switch category {
            case .deepWork: optimalHours = [9, 10, 11]
            case .creative: optimalHours = [15, 16, 17]
            case .shallowWork: optimalHours = [13, 14, 15]
            case .exercise: optimalHours = [17, 18, 19]
            case .meetings: optimalHours = [11, 14, 15]
            case .planning: optimalHours = [8, 9]
            default: optimalHours = [9, 10, 14, 15]
            }

            if let slot = availableSlots.first(where: { slot in
                let hour = calendar.component(.hour, from: slot.start)
                return optimalHours.contains(hour)
            }) {
                let endTime = calendar.date(byAdding: .minute, value: duration, to: slot.start) ?? slot.end

                suggestions.append(SmartTimeBlockSuggestion(
                    id: UUID(),
                    loop: loop,
                    suggestedStartTime: slot.start,
                    suggestedEndTime: endTime,
                    energyLevel: 0.7, // Default
                    category: category,
                    reason: "Scheduled based on research-backed optimal times for \(category.displayName.lowercased())",
                    confidence: 0.6,
                    alternativeTimes: [],
                    isValueAligned: false
                ))
            }
        }

        return suggestions
    }
}

// MARK: - Data Models

/// User's personal energy profile, built from self-assessment and calendar analysis
struct EnergyProfile: Codable {
    var chronotype: Chronotype
    var hourlyEnergyLevels: [Int: Double] // Hour (0-23) -> Energy level (0.0-1.0)
    var userDrawnCurve: [CGPoint]? // User's self-drawn energy curve
    var calendarDerivedPattern: [Int: Double]? // From calendar analysis
    var preferredWorkHours: ClosedRange<Int>
    var preferredExerciseTime: ExerciseTimePreference
    var lastUpdated: Date

    // Default profile based on research (most people are "third birds")
    static var `default`: EnergyProfile {
        var hourlyLevels: [Int: Double] = [:]

        // Research-based default curve for "third bird" chronotype
        // Wake: 7 AM, Peak: 10-11 AM, Trough: 2-3 PM, Recovery peak: 4-6 PM
        for hour in 0...23 {
            switch hour {
            case 0...5: hourlyLevels[hour] = 0.1 // Deep sleep
            case 6: hourlyLevels[hour] = 0.3 // Waking
            case 7: hourlyLevels[hour] = 0.5 // Morning routine
            case 8: hourlyLevels[hour] = 0.7 // Rising
            case 9: hourlyLevels[hour] = 0.85 // Approaching peak
            case 10, 11: hourlyLevels[hour] = 1.0 // Peak alertness
            case 12: hourlyLevels[hour] = 0.8 // Pre-lunch
            case 13: hourlyLevels[hour] = 0.5 // Post-lunch dip begins
            case 14, 15: hourlyLevels[hour] = 0.4 // Afternoon trough
            case 16: hourlyLevels[hour] = 0.6 // Recovery begins
            case 17, 18: hourlyLevels[hour] = 0.7 // Second wind
            case 19: hourlyLevels[hour] = 0.6 // Evening decline
            case 20, 21: hourlyLevels[hour] = 0.5 // Winding down
            case 22, 23: hourlyLevels[hour] = 0.3 // Pre-sleep
            default: hourlyLevels[hour] = 0.5
            }
        }

        return EnergyProfile(
            chronotype: .thirdBird,
            hourlyEnergyLevels: hourlyLevels,
            userDrawnCurve: nil,
            calendarDerivedPattern: nil,
            preferredWorkHours: 8...18,
            preferredExerciseTime: .evening,
            lastUpdated: Date()
        )
    }

    /// Get energy level for a specific hour (0.0 - 1.0)
    func energyAt(hour: Int) -> Double {
        // Prioritize user-drawn curve, then calendar-derived, then defaults
        if let drawn = userDrawnCurve, !drawn.isEmpty {
            // Interpolate from drawn curve
            let normalizedHour = Double(hour) / 24.0
            // Find closest point
            let closest = drawn.min(by: { abs($0.x - normalizedHour) < abs($1.x - normalizedHour) })
            if let y = closest?.y {
                return Double(y)
            }
            return hourlyEnergyLevels[hour] ?? 0.5
        }

        if let calendarPattern = calendarDerivedPattern, let level = calendarPattern[hour] {
            // Blend calendar-derived with defaults
            let defaultLevel = hourlyEnergyLevels[hour] ?? 0.5
            return (level + defaultLevel) / 2.0
        }

        return hourlyEnergyLevels[hour] ?? 0.5
    }

    /// Get optimal hours for a task category
    func optimalHoursFor(category: TaskCategory) -> [Int] {
        // Sort hours by energy level and filter based on task requirements
        let sortedHours = hourlyEnergyLevels.sorted { $0.value > $1.value }

        switch category {
        case .deepWork, .planning:
            // Need highest energy - top 20% of hours
            return sortedHours.prefix(5).map { $0.key }.filter { preferredWorkHours.contains($0) }

        case .creative:
            // Moderate energy is actually better (openness increases with slight fatigue)
            return sortedHours.filter { $0.value > 0.3 && $0.value < 0.7 }.map { $0.key }.filter { preferredWorkHours.contains($0) }

        case .shallowWork:
            // Low-to-moderate energy is fine
            return sortedHours.filter { $0.value > 0.2 && $0.value < 0.6 }.map { $0.key }.filter { preferredWorkHours.contains($0) }

        case .exercise:
            switch preferredExerciseTime {
            case .morning: return [6, 7, 8]
            case .midday: return [11, 12, 13]
            case .evening: return [17, 18, 19]
            }

        case .meetings:
            // Moderate energy, not during peak deep work time
            return sortedHours.filter { $0.value > 0.4 && $0.value < 0.9 }.map { $0.key }.filter { preferredWorkHours.contains($0) }

        case .recovery:
            // During troughs
            return sortedHours.filter { $0.value < 0.4 }.map { $0.key }

        case .other:
            return Array(preferredWorkHours)
        }
    }
}

/// Chronotype classification
enum Chronotype: String, Codable, CaseIterable {
    case morningLark = "lark"      // 15% of population - peak: 9-10 AM
    case thirdBird = "third_bird"  // 65% of population - peak: 10-11 AM
    case nightOwl = "owl"          // 20% of population - peak: 4-9 PM

    var displayName: String {
        switch self {
        case .morningLark: return "Morning Lark"
        case .thirdBird: return "Third Bird"
        case .nightOwl: return "Night Owl"
        }
    }

    var description: String {
        switch self {
        case .morningLark: return "You wake up energized and peak early. Your best work happens before noon."
        case .thirdBird: return "You follow the typical pattern - alert mid-morning, dip after lunch, second wind in late afternoon."
        case .nightOwl: return "You come alive in the evening. Your creativity and focus peak after others wind down."
        }
    }

    var peakHours: ClosedRange<Int> {
        switch self {
        case .morningLark: return 8...11
        case .thirdBird: return 10...12
        case .nightOwl: return 16...21
        }
    }

    var troughHours: ClosedRange<Int> {
        switch self {
        case .morningLark: return 13...15
        case .thirdBird: return 14...16
        case .nightOwl: return 9...12
        }
    }
}

enum ExerciseTimePreference: String, Codable, CaseIterable {
    case morning
    case midday
    case evening

    var displayName: String {
        switch self {
        case .morning: return "Morning (6-9 AM)"
        case .midday: return "Midday (11 AM-1 PM)"
        case .evening: return "Evening (5-8 PM)"
        }
    }

    var benefits: String {
        switch self {
        case .morning: return "Better sleep, faster fat loss, higher cortisol boost"
        case .midday: return "Energy boost for afternoon, stress relief"
        case .evening: return "Peak performance, better muscle gains, social activity"
        }
    }
}

/// Task category for cognitive load matching
enum TaskCategory: String, Codable, CaseIterable {
    case deepWork       // High cognitive load: coding, writing, analysis
    case creative       // Moderate-high, benefits from diffuse thinking
    case shallowWork    // Low cognitive load: emails, admin, routine
    case exercise       // Physical, affects mental state
    case meetings       // Social, variable cognitive load
    case planning       // Strategic thinking, needs clarity
    case recovery       // Breaks, rest, recuperation
    case other

    var displayName: String {
        switch self {
        case .deepWork: return "Deep Work"
        case .creative: return "Creative"
        case .shallowWork: return "Shallow Work"
        case .exercise: return "Exercise"
        case .meetings: return "Meetings"
        case .planning: return "Planning"
        case .recovery: return "Recovery"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .deepWork: return "brain.head.profile"
        case .creative: return "paintbrush.fill"
        case .shallowWork: return "envelope.fill"
        case .exercise: return "figure.run"
        case .meetings: return "person.3.fill"
        case .planning: return "map.fill"
        case .recovery: return "moon.zzz.fill"
        case .other: return "circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .deepWork: return .purple
        case .creative: return .orange
        case .shallowWork: return .gray
        case .exercise: return .green
        case .meetings: return .blue
        case .planning: return .indigo
        case .recovery: return .mint
        case .other: return .secondary
        }
    }

    var cognitiveLoad: Double {
        switch self {
        case .deepWork: return 0.9
        case .creative: return 0.7
        case .shallowWork: return 0.3
        case .exercise: return 0.2
        case .meetings: return 0.5
        case .planning: return 0.8
        case .recovery: return 0.1
        case .other: return 0.5
        }
    }
}

/// Smart time block suggestion with reasoning
struct SmartTimeBlockSuggestion: Identifiable {
    let id: UUID
    let loop: OpenLoopModel
    let suggestedStartTime: Date
    let suggestedEndTime: Date
    let energyLevel: Double // 0.0 - 1.0, energy at suggested time
    let category: TaskCategory
    let reason: String
    let confidence: Double // 0.0 - 1.0, how confident we are in this suggestion
    let alternativeTimes: [EnergyTimeSlot]
    var isValueAligned: Bool = false  // Whether this task aligns with user's core values

    var duration: TimeInterval {
        suggestedEndTime.timeIntervalSince(suggestedStartTime)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    /// Badge text for UI display
    var valueBadge: String? {
        isValueAligned ? "Values" : nil
    }
}

struct EnergyTimeSlot: Equatable {
    let start: Date
    let end: Date
}

// MARK: - Calendar Analysis Models

struct CategorizedEvent {
    let title: String
    let startDate: Date
    let endDate: Date
    let category: TaskCategory
}

struct TaskCompletionPattern {
    let hour: Int
    let dayOfWeek: Int
    let taskType: TaskCategory
    let duration: Double // minutes
}

struct DetectedPattern {
    enum PatternType {
        case peakActivityTime
        case meetingHeavyDay
        case productivePeak
        case energyDip
        case consistentRoutine
    }

    let type: PatternType
    let taskCategory: TaskCategory
    var hour: Int? = nil
    var dayOfWeek: Int? = nil
    let confidence: Double
    let description: String
}

struct CalendarAnalysisResult {
    let patterns: [DetectedPattern]
    let insights: [EnergyInsight]
    let error: String?
}

struct EnergyInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let recommendation: String
    let icon: String
    let priority: InsightPriority

    enum InsightPriority {
        case high, medium, low
    }
}

// MARK: - Preview Support
#if DEBUG
extension EnergyProfile {
    static var preview: EnergyProfile {
        .default
    }
}

extension SmartTimeBlockSuggestion {
    static var preview: SmartTimeBlockSuggestion {
        SmartTimeBlockSuggestion(
            id: UUID(),
            loop: OpenLoopModel(content: "Write quarterly report", importance: 1),
            suggestedStartTime: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!,
            suggestedEndTime: Calendar.current.date(bySettingHour: 11, minute: 30, second: 0, of: Date())!,
            energyLevel: 0.9,
            category: TaskCategory.deepWork,
            reason: "Scheduled during your peak energy window when focus is highest",
            confidence: 0.85,
            alternativeTimes: [],
            isValueAligned: true
        )
    }
}
#endif
