//
//  MemoryService.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Persistent AI memory management - store, retrieve, and forget facts
//

import Foundation
import SwiftData

// MARK: - Memory Service

/// Manages AI memory - stores facts about the user, retrieves relevant context,
/// and handles memory decay/forgetting based on priority and access patterns
@MainActor
class MemoryService: ObservableObject {
    static let shared = MemoryService()

    // Memory limits
    private let maxMemoryItems = 100
    private let maxContextItems = 20  // Max items to inject into AI prompts

    private init() {}

    // MARK: - Store Memory

    /// Adds a new memory item to the user's profile
    func remember(
        _ content: String,
        category: MemoryCategory,
        priority: MemoryPriority,
        profile: UserProfileModel
    ) {
        var memories = profile.rememberedFacts

        // Check for duplicates or updates
        if let existingIndex = memories.firstIndex(where: { $0.content.lowercased() == content.lowercased() }) {
            // Update existing memory
            var existing = memories[existingIndex]
            existing.lastAccessed = Date()
            existing.accessCount += 1
            // Upgrade priority if new one is higher
            if priority.rawValue > existing.priority.rawValue {
                existing.priority = priority
            }
            memories[existingIndex] = existing
        } else {
            // Add new memory
            let newMemory = MemoryItem(content: content, category: category, priority: priority)
            memories.append(newMemory)
        }

        // Enforce memory limits - remove lowest priority, oldest items
        memories = enforceMemoryLimits(memories)

        profile.rememberedFacts = memories
        profile.lastUpdated = Date()
    }

    /// Stores multiple memories at once (e.g., from values quiz results)
    func rememberBatch(
        _ items: [(content: String, category: MemoryCategory, priority: MemoryPriority)],
        profile: UserProfileModel
    ) {
        for item in items {
            remember(item.content, category: item.category, priority: item.priority, profile: profile)
        }
    }

    // MARK: - Retrieve Memory

    /// Gets all memories for a specific category
    func getMemories(for category: MemoryCategory, from profile: UserProfileModel) -> [MemoryItem] {
        return profile.rememberedFacts.filter { $0.category == category }
    }

    /// Gets memories sorted by priority and recency for AI context injection
    func getContextMemories(from profile: UserProfileModel, maxItems: Int? = nil) -> [MemoryItem] {
        let limit = maxItems ?? maxContextItems

        // Sort by priority (high to low), then by last accessed (recent first)
        let sorted = profile.rememberedFacts.sorted { a, b in
            if a.priority.rawValue != b.priority.rawValue {
                return a.priority.rawValue > b.priority.rawValue
            }
            return a.lastAccessed > b.lastAccessed
        }

        // Mark items as accessed
        var memories = profile.rememberedFacts
        for item in sorted.prefix(limit) {
            if let index = memories.firstIndex(where: { $0.id == item.id }) {
                memories[index].lastAccessed = Date()
                memories[index].accessCount += 1
            }
        }
        profile.rememberedFacts = memories

        return Array(sorted.prefix(limit))
    }

    /// Searches memories for relevant content
    func search(_ query: String, in profile: UserProfileModel) -> [MemoryItem] {
        let lowercaseQuery = query.lowercased()
        return profile.rememberedFacts.filter {
            $0.content.lowercased().contains(lowercaseQuery)
        }
    }

    // MARK: - Update Memory

    /// Updates an existing memory's content
    func update(memoryId: UUID, newContent: String, in profile: UserProfileModel) {
        var memories = profile.rememberedFacts
        if let index = memories.firstIndex(where: { $0.id == memoryId }) {
            memories[index].content = newContent
            memories[index].lastAccessed = Date()
            profile.rememberedFacts = memories
            profile.lastUpdated = Date()
        }
    }

    /// Records a user correction (e.g., "Actually, call me Sam not Sarah")
    func recordCorrection(_ correction: String, profile: UserProfileModel) {
        remember(correction, category: .corrections, priority: .high, profile: profile)
    }

    // MARK: - Forget Memory

    /// Removes a specific memory
    func forget(memoryId: UUID, from profile: UserProfileModel) {
        var memories = profile.rememberedFacts
        memories.removeAll { $0.id == memoryId }
        profile.rememberedFacts = memories
        profile.lastUpdated = Date()
    }

    /// Removes all memories in a category
    func forgetCategory(_ category: MemoryCategory, from profile: UserProfileModel) {
        var memories = profile.rememberedFacts
        memories.removeAll { $0.category == category }
        profile.rememberedFacts = memories
        profile.lastUpdated = Date()
    }

    /// Removes ephemeral memories (priority = 1, session-only data)
    func forgetEphemeral(from profile: UserProfileModel) {
        var memories = profile.rememberedFacts
        memories.removeAll { $0.priority == .ephemeral }
        profile.rememberedFacts = memories
    }

    /// Clears all memories (full reset)
    func forgetAll(from profile: UserProfileModel) {
        profile.rememberedFacts = []
        profile.lastUpdated = Date()
    }

    // MARK: - Memory Maintenance

    /// Enforces memory limits by removing lowest priority, oldest items
    private func enforceMemoryLimits(_ memories: [MemoryItem]) -> [MemoryItem] {
        guard memories.count > maxMemoryItems else { return memories }

        // Sort by priority (low to high) then by last accessed (oldest first)
        // This puts the most "forgettable" items first
        let sorted = memories.sorted { a, b in
            if a.priority.rawValue != b.priority.rawValue {
                return a.priority.rawValue < b.priority.rawValue
            }
            return a.lastAccessed < b.lastAccessed
        }

        // Keep only the most important items
        let toKeep = sorted.suffix(maxMemoryItems)
        return Array(toKeep)
    }

    /// Periodic maintenance - compress old context, remove stale data
    func performMaintenance(on profile: UserProfileModel) {
        var memories = profile.rememberedFacts
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        // Remove ephemeral items older than 1 day
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        memories.removeAll { $0.priority == .ephemeral && $0.lastAccessed < oneDayAgo }

        // Remove low priority items not accessed in 7 days
        memories.removeAll { $0.priority == .low && $0.lastAccessed < sevenDaysAgo && $0.accessCount < 3 }

        // Remove medium priority context items not accessed in 30 days
        memories.removeAll { $0.priority == .medium && $0.category == .context && $0.lastAccessed < thirtyDaysAgo }

        profile.rememberedFacts = memories
        profile.lastUpdated = Date()
    }

    // MARK: - AI Prompt Building

    /// Builds a memory context string for injection into AI prompts
    func buildMemoryContext(from profile: UserProfileModel) -> String {
        let memories = getContextMemories(from: profile)

        guard !memories.isEmpty else {
            return ""
        }

        var context = "REMEMBERED ABOUT USER:\n"

        // Group by category for cleaner output
        let grouped = Dictionary(grouping: memories) { $0.category }

        // Identity first
        if let identity = grouped[.identity], !identity.isEmpty {
            context += "Identity:\n"
            for item in identity {
                context += "- \(item.content)\n"
            }
        }

        // Values
        if let values = grouped[.values], !values.isEmpty {
            context += "Values:\n"
            for item in values {
                context += "- \(item.content)\n"
            }
        }

        // Goals
        if let goals = grouped[.goals], !goals.isEmpty {
            context += "Goals:\n"
            for item in goals {
                context += "- \(item.content)\n"
            }
        }

        // Preferences
        if let prefs = grouped[.preferences], !prefs.isEmpty {
            context += "Preferences:\n"
            for item in prefs {
                context += "- \(item.content)\n"
            }
        }

        // Corrections (important - overrides other info)
        if let corrections = grouped[.corrections], !corrections.isEmpty {
            context += "User Corrections:\n"
            for item in corrections {
                context += "- \(item.content)\n"
            }
        }

        // Recent context
        if let recent = grouped[.context], !recent.isEmpty {
            context += "Recent Context:\n"
            for item in recent.prefix(5) {
                context += "- \(item.content)\n"
            }
        }

        // Patterns
        if let patterns = grouped[.patterns], !patterns.isEmpty {
            context += "Observed Patterns:\n"
            for item in patterns.prefix(3) {
                context += "- \(item.content)\n"
            }
        }

        return context
    }

    // MARK: - Memory Extraction from Conversations

    /// Extracts memorable facts from a user message
    /// Called after each user message to potentially store new memories
    func extractAndStoreMemories(from message: String, profile: UserProfileModel) {
        let lowercased = message.lowercased()

        // Name detection
        if let name = extractName(from: message) {
            remember("User's name is \(name)", category: .identity, priority: .critical, profile: profile)
        }

        // Correction detection
        if lowercased.contains("actually") || lowercased.contains("prefer") || lowercased.contains("call me") {
            remember("User correction: \(message)", category: .corrections, priority: .high, profile: profile)
        }

        // Goal detection
        let goalKeywords = ["i want to", "my goal is", "i'm trying to", "i need to", "working on"]
        for keyword in goalKeywords {
            if lowercased.contains(keyword) {
                remember("User goal/intention: \(message)", category: .goals, priority: .high, profile: profile)
                break
            }
        }

        // Preference detection
        let prefKeywords = ["i like", "i prefer", "i don't like", "i hate", "i love"]
        for keyword in prefKeywords {
            if lowercased.contains(keyword) {
                remember("User preference: \(message)", category: .preferences, priority: .medium, profile: profile)
                break
            }
        }
    }

    /// Extracts a name from common patterns
    private func extractName(from message: String) -> String? {
        let patterns = [
            "my name is ",
            "i'm ",
            "i am ",
            "call me ",
            "this is "
        ]

        let lowercased = message.lowercased()
        for pattern in patterns {
            if let range = lowercased.range(of: pattern) {
                let afterPattern = message[range.upperBound...]
                // Get the first word after the pattern
                let words = afterPattern.split(separator: " ")
                if let firstWord = words.first {
                    let name = String(firstWord).trimmingCharacters(in: .punctuationCharacters)
                    // Basic validation - should be capitalized and not too long
                    if name.count >= 2 && name.count <= 20 {
                        return name.capitalized
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Initial Memory Seeding

    /// Seeds initial memories from onboarding results (values quiz, name, etc.)
    func seedFromOnboarding(
        name: String?,
        coreValues: [SchwartzValue],
        communicationStyle: CommunicationTone,
        profile: UserProfileModel
    ) {
        // Name
        if let name = name, !name.isEmpty {
            remember("User's name is \(name)", category: .identity, priority: .critical, profile: profile)
        }

        // Core values
        for value in coreValues {
            remember(
                "User values \(value.rawValue.lowercased()): \(value.description)",
                category: .values,
                priority: .critical,
                profile: profile
            )
        }

        // Communication preference
        remember(
            "User prefers \(communicationStyle.rawValue) communication: \(communicationStyle.description)",
            category: .preferences,
            priority: .high,
            profile: profile
        )
    }
}

// MARK: - Memory Statistics

extension MemoryService {
    /// Returns statistics about the user's memory storage
    func getStatistics(from profile: UserProfileModel) -> MemoryStatistics {
        let memories = profile.rememberedFacts

        let byCategory = Dictionary(grouping: memories) { $0.category }
        let byPriority = Dictionary(grouping: memories) { $0.priority }

        return MemoryStatistics(
            totalCount: memories.count,
            byCategoryCount: byCategory.mapValues { $0.count },
            byPriorityCount: byPriority.mapValues { $0.count },
            oldestMemory: memories.min(by: { $0.createdAt < $1.createdAt })?.createdAt,
            newestMemory: memories.max(by: { $0.createdAt < $1.createdAt })?.createdAt,
            mostAccessed: memories.max(by: { $0.accessCount < $1.accessCount })
        )
    }
}

struct MemoryStatistics {
    let totalCount: Int
    let byCategoryCount: [MemoryCategory: Int]
    let byPriorityCount: [MemoryPriority: Int]
    let oldestMemory: Date?
    let newestMemory: Date?
    let mostAccessed: MemoryItem?
}
