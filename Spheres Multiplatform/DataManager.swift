//
//  DataManager.swift
//  Spheres - Smart Life Manager
//
//  Handles data operations and initial seeding
//

import SwiftUI
import SwiftData

// MARK: - Data Manager
@MainActor
class DataManager {
    static let shared = DataManager()

    private init() {}

    // MARK: - One-time cleanup of default spheres and sample loops
    private let defaultSphereNames: Set<String> = [
        "Spiritual", "Health", "Family", "Career", "Education", "Creative"
    ]

    func cleanupDefaultDataIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: "hasCleanedDefaultSpheres") else { return }
        do {
            let allSpheres = try modelContext.fetch(FetchDescriptor<SphereModel>())
            for sphere in allSpheres where defaultSphereNames.contains(sphere.name) {
                // Cascade delete removes associated loops
                modelContext.delete(sphere)
            }
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: "hasCleanedDefaultSpheres")
            UserDefaults.standard.set(true, forKey: "hasCleanedSampleLoops")
            print("DEBUG: Cleaned up default spheres and sample loops")
        } catch {
            print("DEBUG: Error cleaning default data: \(error)")
        }
    }

    // MARK: - Sphere Operations
    func createSphere(
        name: String,
        icon: String,
        color: Color,
        description: String,
        priorityRank: Int,
        customImageData: Data?,
        modelContext: ModelContext
    ) -> SphereModel {
        let sphere = SphereModel(
            name: name,
            icon: icon,
            color: color,
            description: description,
            priorityRank: priorityRank,
            customImageData: customImageData
        )
        modelContext.insert(sphere)
        try? modelContext.save()
        return sphere
    }

    func deleteSphere(_ sphere: SphereModel, modelContext: ModelContext) {
        modelContext.delete(sphere)
        try? modelContext.save()
    }

    // MARK: - Loop Operations
    func createLoop(
        content: String,
        sphere: SphereModel?,
        importance: Int,
        progress: Double,
        estimatedMinutes: Int?,
        modelContext: ModelContext
    ) -> OpenLoopModel {
        let loop = OpenLoopModel(
            content: content,
            sphere: sphere,
            importance: importance,
            progress: progress,
            estimatedMinutes: estimatedMinutes
        )
        modelContext.insert(loop)
        try? modelContext.save()
        return loop
    }

    func deleteLoop(_ loop: OpenLoopModel, modelContext: ModelContext) {
        modelContext.delete(loop)
        try? modelContext.save()
    }

    func toggleLoopCompletion(_ loop: OpenLoopModel, modelContext: ModelContext) {
        loop.isCompleted.toggle()
        if loop.isCompleted {
            loop.progress = 1.0
            loop.completedDate = Date()
            // Stop timer if running
            if loop.timerStartDate != nil {
                stopTimer(loop, modelContext: modelContext)
            }
            // Handle streak for habits
            if loop.isHabit {
                updateStreak(loop)
            }
            // Handle recurring tasks - schedule next occurrence
            if loop.isRecurring {
                scheduleNextOccurrence(loop, modelContext: modelContext)
            }
        } else {
            loop.completedDate = nil
        }
        try? modelContext.save()
    }

    // MARK: - Recurring Task Operations
    private func scheduleNextOccurrence(_ loop: OpenLoopModel, modelContext: ModelContext) {
        guard loop.isRecurring else { return }

        // Calculate next due date
        if let nextDate = loop.calculateNextOccurrence(from: loop.dueDate ?? Date()) {
            loop.nextOccurrence = nextDate
        }
    }

    func createNextRecurrence(_ loop: OpenLoopModel, modelContext: ModelContext) -> OpenLoopModel? {
        guard loop.isRecurring, let nextDate = loop.nextOccurrence ?? loop.calculateNextOccurrence() else {
            return nil
        }

        // Create a new loop for the next occurrence
        let newLoop = OpenLoopModel(
            content: loop.content,
            sphere: loop.sphere,
            importance: loop.importance,
            progress: 0.0,
            estimatedMinutes: loop.estimatedMinutes,
            dueDate: nextDate,
            isHabit: loop.isHabit,
            isRecurring: loop.isRecurring,
            recurrenceType: loop.recurrenceType
        )
        newLoop.recurrenceInterval = loop.recurrenceInterval
        newLoop.recurrenceDays = loop.recurrenceDays

        modelContext.insert(newLoop)
        try? modelContext.save()
        return newLoop
    }

    func updateRecurrence(
        _ loop: OpenLoopModel,
        isRecurring: Bool,
        recurrenceType: RecurrenceType,
        interval: Int,
        modelContext: ModelContext
    ) {
        loop.isRecurring = isRecurring
        loop.recurrenceType = recurrenceType.rawValue
        loop.recurrenceInterval = interval
        if isRecurring {
            loop.nextOccurrence = loop.calculateNextOccurrence()
        } else {
            loop.nextOccurrence = nil
        }
        try? modelContext.save()
    }

    // MARK: - Timer Operations
    func startTimer(_ loop: OpenLoopModel, modelContext: ModelContext) {
        guard loop.timerStartDate == nil else { return }
        loop.timerStartDate = Date()
        try? modelContext.save()
    }

    func stopTimer(_ loop: OpenLoopModel, modelContext: ModelContext) {
        guard let startDate = loop.timerStartDate else { return }
        let elapsed = Int(Date().timeIntervalSince(startDate))
        loop.timeSpentSeconds += elapsed
        loop.timerStartDate = nil
        try? modelContext.save()
    }

    func toggleTimer(_ loop: OpenLoopModel, modelContext: ModelContext) {
        if loop.timerStartDate != nil {
            stopTimer(loop, modelContext: modelContext)
        } else {
            startTimer(loop, modelContext: modelContext)
        }
    }

    // MARK: - Streak Operations
    private func updateStreak(_ loop: OpenLoopModel) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastCompleted = loop.lastCompletedDate {
            let lastDay = calendar.startOfDay(for: lastCompleted)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 1 {
                // Consecutive day - increment streak
                loop.currentStreak += 1
            } else if daysDiff > 1 {
                // Streak broken - reset to 1
                loop.currentStreak = 1
            }
            // daysDiff == 0 means same day, don't change streak
        } else {
            // First completion
            loop.currentStreak = 1
        }
        loop.lastCompletedDate = today
    }

    func resetHabitForNewDay(_ loop: OpenLoopModel, modelContext: ModelContext) {
        guard loop.isHabit else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastCompleted = loop.lastCompletedDate {
            let lastDay = calendar.startOfDay(for: lastCompleted)
            if lastDay < today {
                // New day - reset completion status
                loop.isCompleted = false
                loop.progress = 0.0
                loop.completedDate = nil

                // Check if streak is broken (more than 1 day gap)
                let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
                if daysDiff > 1 {
                    loop.currentStreak = 0
                }
            }
        }
        try? modelContext.save()
    }

    func toggleHabit(_ loop: OpenLoopModel, modelContext: ModelContext) {
        loop.isHabit.toggle()
        if !loop.isHabit {
            loop.currentStreak = 0
            loop.lastCompletedDate = nil
        }
        try? modelContext.save()
    }

    func updateLoopProgress(_ loop: OpenLoopModel, progress: Double, modelContext: ModelContext) {
        loop.progress = progress
        if progress >= 1.0 {
            loop.isCompleted = true
        }
        try? modelContext.save()
    }

    func updateLoop(
        _ loop: OpenLoopModel,
        content: String? = nil,
        sphere: SphereModel? = nil,
        importance: Int? = nil,
        progress: Double? = nil,
        estimatedMinutes: Int? = nil,
        dueDate: Date? = nil,
        clearDueDate: Bool = false,
        modelContext: ModelContext
    ) {
        if let content = content {
            loop.content = content
        }
        if let sphere = sphere {
            loop.sphere = sphere
        }
        if let importance = importance {
            loop.importance = importance
        }
        if let progress = progress {
            loop.progress = progress
            if progress >= 1.0 {
                loop.isCompleted = true
            }
        }
        if let estimatedMinutes = estimatedMinutes {
            loop.estimatedMinutes = estimatedMinutes
        }
        if clearDueDate {
            loop.dueDate = nil
        } else if let dueDate = dueDate {
            loop.dueDate = dueDate
        }
        try? modelContext.save()
    }

    // MARK: - Inbox Operations
    func createInboxItem(content: String, modelContext: ModelContext) -> InboxItemModel {
        let item = InboxItemModel(content: content)
        modelContext.insert(item)
        try? modelContext.save()
        return item
    }

    func processInboxItem(_ item: InboxItemModel, toSphere sphere: SphereModel, importance: Int, modelContext: ModelContext) {
        // Create a loop from the inbox item
        let loop = OpenLoopModel(
            content: item.content,
            sphere: sphere,
            importance: importance
        )
        modelContext.insert(loop)

        // Mark inbox item as processed or delete it
        modelContext.delete(item)
        try? modelContext.save()
    }

    func deleteInboxItem(_ item: InboxItemModel, modelContext: ModelContext) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    // MARK: - Export Operations

    func exportToJSON(modelContext: ModelContext) -> Data? {
        do {
            let spheres = try modelContext.fetch(FetchDescriptor<SphereModel>(sortBy: [SortDescriptor(\.priorityRank)]))
            let loops = try modelContext.fetch(FetchDescriptor<OpenLoopModel>(sortBy: [SortDescriptor(\.createdDate)]))
            let inbox = try modelContext.fetch(FetchDescriptor<InboxItemModel>(sortBy: [SortDescriptor(\.capturedDate)]))

            let exportData: [String: Any] = [
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "version": "1.0",
                "spheres": spheres.map { sphere in
                    [
                        "id": sphere.id.uuidString,
                        "name": sphere.name,
                        "icon": sphere.icon,
                        "description": sphere.sphereDescription,
                        "priorityRank": sphere.priorityRank,
                        "colorRed": sphere.colorRed,
                        "colorGreen": sphere.colorGreen,
                        "colorBlue": sphere.colorBlue,
                        "createdDate": ISO8601DateFormatter().string(from: sphere.createdDate)
                    ] as [String: Any]
                },
                "loops": loops.map { loop in
                    var dict: [String: Any] = [
                        "id": loop.id.uuidString,
                        "content": loop.content,
                        "importance": loop.importance,
                        "progress": loop.progress,
                        "isCompleted": loop.isCompleted,
                        "timeSpentSeconds": loop.timeSpentSeconds,
                        "isHabit": loop.isHabit,
                        "currentStreak": loop.currentStreak,
                        "isRecurring": loop.isRecurring,
                        "recurrenceType": loop.recurrenceType,
                        "recurrenceInterval": loop.recurrenceInterval,
                        "createdDate": ISO8601DateFormatter().string(from: loop.createdDate)
                    ]
                    if let sphere = loop.sphere { dict["sphereId"] = sphere.id.uuidString }
                    if let mins = loop.estimatedMinutes { dict["estimatedMinutes"] = mins }
                    if let due = loop.dueDate { dict["dueDate"] = ISO8601DateFormatter().string(from: due) }
                    if let completed = loop.completedDate { dict["completedDate"] = ISO8601DateFormatter().string(from: completed) }
                    return dict
                },
                "inboxItems": inbox.map { item in
                    [
                        "id": item.id.uuidString,
                        "content": item.content,
                        "capturedDate": ISO8601DateFormatter().string(from: item.capturedDate),
                        "isProcessed": item.isProcessed
                    ] as [String: Any]
                }
            ]

            return try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
        } catch {
            print("Export failed: \(error)")
            return nil
        }
    }

    func exportToCSV(modelContext: ModelContext) -> String? {
        do {
            let loops = try modelContext.fetch(FetchDescriptor<OpenLoopModel>(sortBy: [SortDescriptor(\.createdDate)]))

            var csv = "Content,Sphere,Priority,Progress,Completed,Time Spent (min),Due Date,Habit,Streak,Recurring,Recurrence,Created\n"

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for loop in loops {
                let sphere = loop.sphere?.name ?? ""
                let due = loop.dueDate.map { dateFormatter.string(from: $0) } ?? ""
                let created = dateFormatter.string(from: loop.createdDate)
                let content = loop.content.replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ")

                csv += "\"\(content)\",\(sphere),\(loop.importance),\(Int(loop.progress * 100))%,\(loop.isCompleted),\(loop.timeSpentSeconds / 60),\(due),\(loop.isHabit),\(loop.currentStreak),\(loop.isRecurring),\(loop.recurrenceDescription),\(created)\n"
            }
            return csv
        } catch {
            print("CSV export failed: \(error)")
            return nil
        }
    }

    // MARK: - Backup & Restore

    func createBackup(modelContext: ModelContext) -> URL? {
        guard let jsonData = exportToJSON(modelContext: modelContext) else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "Spheres_Backup_\(timestamp).json"

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupURL = documentsPath.appendingPathComponent(filename)

        do {
            try jsonData.write(to: backupURL)
            return backupURL
        } catch {
            print("Backup failed: \(error)")
            return nil
        }
    }

    // MARK: - Clear All Data (for Onboarding Reset)

    /// Clears all spheres, loops, inbox items, and user profile data
    /// Used when user wants to restart onboarding or test the quiz fresh
    func clearAllDataForOnboarding(modelContext: ModelContext) {
        do {
            // Delete all spheres (cascades to loops via relationship)
            let spheres = try modelContext.fetch(FetchDescriptor<SphereModel>())
            for sphere in spheres {
                modelContext.delete(sphere)
            }

            // Delete any orphaned loops (shouldn't exist but just in case)
            let loops = try modelContext.fetch(FetchDescriptor<OpenLoopModel>())
            for loop in loops {
                modelContext.delete(loop)
            }

            // Delete all inbox items
            let inboxItems = try modelContext.fetch(FetchDescriptor<InboxItemModel>())
            for item in inboxItems {
                modelContext.delete(item)
            }

            // Delete user profile
            let profiles = try modelContext.fetch(FetchDescriptor<UserProfileModel>())
            for profile in profiles {
                modelContext.delete(profile)
            }

            try modelContext.save()

            // Clear onboarding-related UserDefaults
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "hasCompletedEnergyOnboarding")
            UserDefaults.standard.removeObject(forKey: "hasCompletedValuesQuiz")
            UserDefaults.standard.removeObject(forKey: "scheduledLoopIds")
            UserDefaults.standard.removeObject(forKey: "energyProfile")

            print("DEBUG: Cleared all data for onboarding reset")
        } catch {
            print("DEBUG: Error clearing data: \(error)")
        }
    }

    /// Creates a new user profile (used during onboarding)
    func createUserProfile(modelContext: ModelContext) -> UserProfileModel {
        let profile = UserProfileModel()
        modelContext.insert(profile)
        try? modelContext.save()
        return profile
    }

    /// Fetches the current user profile, or creates one if none exists
    func fetchOrCreateUserProfile(modelContext: ModelContext) -> UserProfileModel {
        do {
            let profiles = try modelContext.fetch(FetchDescriptor<UserProfileModel>())
            if let existing = profiles.first {
                return existing
            }
        } catch {
            print("DEBUG: Error fetching profile: \(error)")
        }
        return createUserProfile(modelContext: modelContext)
    }

    func restoreFromBackup(url: URL, modelContext: ModelContext) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }

            // Clear existing data
            let existingSpheres = try modelContext.fetch(FetchDescriptor<SphereModel>())
            for sphere in existingSpheres { modelContext.delete(sphere) }
            let existingLoops = try modelContext.fetch(FetchDescriptor<OpenLoopModel>())
            for loop in existingLoops { modelContext.delete(loop) }
            let existingInbox = try modelContext.fetch(FetchDescriptor<InboxItemModel>())
            for item in existingInbox { modelContext.delete(item) }
            try modelContext.save()

            let isoFormatter = ISO8601DateFormatter()

            // Restore spheres
            var sphereMap: [String: SphereModel] = [:]
            if let spheresData = json["spheres"] as? [[String: Any]] {
                for sphereDict in spheresData {
                    let name = sphereDict["name"] as? String ?? ""
                    let icon = sphereDict["icon"] as? String ?? "circle.fill"
                    let desc = sphereDict["description"] as? String ?? ""
                    let rank = sphereDict["priorityRank"] as? Int ?? 3
                    let r = sphereDict["colorRed"] as? Double ?? 0.5
                    let g = sphereDict["colorGreen"] as? Double ?? 0.5
                    let b = sphereDict["colorBlue"] as? Double ?? 0.5

                    let sphere = SphereModel(name: name, icon: icon, color: Color(red: r, green: g, blue: b), description: desc, priorityRank: rank)
                    modelContext.insert(sphere)

                    if let idStr = sphereDict["id"] as? String {
                        sphereMap[idStr] = sphere
                    }
                }
            }

            // Restore loops
            if let loopsData = json["loops"] as? [[String: Any]] {
                for loopDict in loopsData {
                    let content = loopDict["content"] as? String ?? ""
                    let importance = loopDict["importance"] as? Int ?? 3
                    let progress = loopDict["progress"] as? Double ?? 0.0
                    let isCompleted = loopDict["isCompleted"] as? Bool ?? false
                    let isHabit = loopDict["isHabit"] as? Bool ?? false
                    let isRecurring = loopDict["isRecurring"] as? Bool ?? false
                    let recurrenceType = loopDict["recurrenceType"] as? String ?? "none"

                    let sphereId = loopDict["sphereId"] as? String
                    let sphere = sphereId.flatMap { sphereMap[$0] }
                    let due = (loopDict["dueDate"] as? String).flatMap { isoFormatter.date(from: $0) }

                    let loop = OpenLoopModel(content: content, sphere: sphere, importance: importance, progress: progress, estimatedMinutes: loopDict["estimatedMinutes"] as? Int, dueDate: due, isHabit: isHabit, isRecurring: isRecurring, recurrenceType: recurrenceType)
                    loop.isCompleted = isCompleted
                    loop.timeSpentSeconds = loopDict["timeSpentSeconds"] as? Int ?? 0
                    loop.currentStreak = loopDict["currentStreak"] as? Int ?? 0
                    loop.recurrenceInterval = loopDict["recurrenceInterval"] as? Int ?? 1
                    if let completedStr = loopDict["completedDate"] as? String {
                        loop.completedDate = isoFormatter.date(from: completedStr)
                    }
                    modelContext.insert(loop)
                }
            }

            // Restore inbox
            if let inboxData = json["inboxItems"] as? [[String: Any]] {
                for itemDict in inboxData {
                    let content = itemDict["content"] as? String ?? ""
                    let item = InboxItemModel(content: content)
                    modelContext.insert(item)
                }
            }

            try modelContext.save()
            return true
        } catch {
            print("Restore failed: \(error)")
            return false
        }
    }
}
