//
//  RemindersAdapter.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Extracts tasks from Apple Reminders via EventKit
//

import Foundation
import EventKit

class RemindersAdapter: SourceAdapter {
    let source: TaskSource = .reminders

    private let eventStore = EKEventStore()
    private let taskKeywords = ["todo", "task", "action", "need to", "must", "should", "reminder"]

    func checkPermissions() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        return status == .fullAccess || status == .authorized
    }

    func requestPermissions() async -> Bool {
        do {
            if #available(macOS 14.0, *) {
                return try await eventStore.requestFullAccessToReminders()
            } else {
                return try await eventStore.requestAccess(to: .reminder)
            }
        } catch {
            print("DEBUG: Failed to request Reminders access: \(error)")
            return false
        }
    }

    func extractTasks(since: Date?, limit: Int?) async throws -> [ExtractedTask] {
        guard await checkPermissions() else {
            throw SourceAdapterError.permissionDenied
        }

        // Get all reminder calendars
        let calendars = eventStore.calendars(for: .reminder)

        // Create predicate for incomplete reminders
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: since,
            ending: nil,
            calendars: calendars
        )

        // Fetch reminders
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                guard let reminders = reminders else {
                    continuation.resume(returning: [])
                    return
                }

                var tasks: [ExtractedTask] = []
                let maxCount = limit ?? 50

                for reminder in reminders.prefix(maxCount) {
                    let task = self.convertToExtractedTask(reminder)
                    tasks.append(task)
                }

                continuation.resume(returning: tasks)
            }
        }
    }

    func markAsProcessed(sourceId: String) async {
        // Could mark the reminder as complete or add a tag
        // For now, we just track it in SourceAdapterManager
    }

    private func convertToExtractedTask(_ reminder: EKReminder) -> ExtractedTask {
        // Calculate confidence based on content analysis
        var confidence = 0.8  // Base confidence for Reminders (they're usually tasks)

        let content = reminder.title ?? ""
        let lowercased = content.lowercased()

        // Boost confidence for action-oriented language
        for keyword in taskKeywords {
            if lowercased.contains(keyword) {
                confidence = min(1.0, confidence + 0.05)
            }
        }

        // Boost for having a due date
        if reminder.dueDateComponents != nil {
            confidence = min(1.0, confidence + 0.1)
        }

        // Suggest priority based on reminder priority
        let priority: Int?
        switch reminder.priority {
        case 1: priority = 1  // High
        case 5: priority = 3  // Medium
        case 9: priority = 5  // Low
        default: priority = nil
        }

        // Suggest sphere based on calendar name
        let sphereName = suggestSphereFromCalendarName(reminder.calendar?.title)

        return ExtractedTask(
            content: content,
            source: .reminders,
            sourceId: reminder.calendarItemIdentifier,
            extractedAt: Date(),
            confidence: confidence,
            suggestedSphere: sphereName,
            suggestedPriority: priority,
            context: reminder.calendar?.title
        )
    }

    private func suggestSphereFromCalendarName(_ name: String?) -> String? {
        guard let name = name?.lowercased() else { return nil }

        if name.contains("work") || name.contains("job") || name.contains("career") {
            return "Career"
        } else if name.contains("home") || name.contains("family") || name.contains("personal") {
            return "Family"
        } else if name.contains("health") || name.contains("fitness") || name.contains("gym") {
            return "Health"
        } else if name.contains("learn") || name.contains("study") || name.contains("school") {
            return "Education"
        }

        return nil
    }
}
