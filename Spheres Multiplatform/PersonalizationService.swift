//
//  PersonalizationService.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Coordinates user profile, memory, and AI personalization
//

import Foundation
import SwiftData

// MARK: - Personalization Service

/// Central coordinator for all personalization features
/// - Manages user profile state
/// - Coordinates memory and AI services
/// - Provides personalized content based on user values and preferences
@MainActor
class PersonalizationService: ObservableObject {
    static let shared = PersonalizationService()

    @Published var currentProfile: UserProfileModel?
    @Published var isProfileLoaded = false

    private let memoryService = MemoryService.shared

    private init() {}

    // MARK: - Profile Management

    /// Loads the user profile from the model context
    func loadProfile(modelContext: ModelContext) {
        currentProfile = DataManager.shared.fetchOrCreateUserProfile(modelContext: modelContext)
        isProfileLoaded = true
    }

    /// Gets the personalization depth based on interaction count
    var personalizationDepth: PersonalizationDepth {
        guard let profile = currentProfile else { return .minimal }
        return PersonalizationDepth.forInteractionCount(profile.interactionCount)
    }

    // MARK: - Personalized Greetings

    /// Returns a personalized greeting based on time of day and user profile
    func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String

        switch hour {
        case 5..<12:
            timeGreeting = "Good morning"
        case 12..<17:
            timeGreeting = "Good afternoon"
        case 17..<22:
            timeGreeting = "Good evening"
        default:
            timeGreeting = "Hello"
        }

        guard let profile = currentProfile else {
            return timeGreeting
        }

        // Add name if we know it
        if !profile.displayName.isEmpty {
            switch personalizationDepth {
            case .minimal:
                return timeGreeting
            case .moderate:
                return "\(timeGreeting), \(profile.displayName)"
            case .deep, .complete:
                return "\(timeGreeting), \(profile.displayName)"
            }
        }

        return timeGreeting
    }

    /// Returns a personalized subtitle for the home view
    func getHomeSubtitle(openLoopCount: Int, highPriorityCount: Int) -> String {
        guard let profile = currentProfile, personalizationDepth.rawValue >= PersonalizationDepth.deep.rawValue else {
            if highPriorityCount > 0 {
                return "You have \(highPriorityCount) high-priority items"
            }
            return "You have \(openLoopCount) open loops"
        }

        // Personalized based on values
        let topValue = profile.topValues(count: 1).first

        if highPriorityCount == 0 {
            return "A clear day ahead. What matters most?"
        }

        if let value = topValue {
            switch value {
            case .achievement:
                return "Ready to make progress on your \(highPriorityCount) priority items?"
            case .benevolence, .universalism:
                return "Balance your \(highPriorityCount) tasks with time for others"
            case .security:
                return "Tackle your \(highPriorityCount) priorities for peace of mind"
            case .selfDirection:
                return "You have \(highPriorityCount) items - schedule them your way"
            case .stimulation:
                return "\(highPriorityCount) challenges await - which excites you most?"
            default:
                return "You have \(highPriorityCount) high-priority items"
            }
        }

        return "You have \(highPriorityCount) high-priority items"
    }

    // MARK: - AI Prompt Personalization

    /// Builds a personalized system prompt for the AI based on user profile
    func buildPersonalizedSystemPrompt() -> String {
        guard let profile = currentProfile else {
            return defaultSystemPrompt
        }

        var prompt = """
        You are a gentle, reliable companion in the Spheres productivity app.
        You help users manage their life across different spheres (areas of focus).

        """

        // Add user identity
        if !profile.displayName.isEmpty {
            prompt += "USER: \(profile.displayName)\n"
        }

        // Add orientation type (primary personalization)
        let orientationType = profile.orientationProfile.primaryType
        prompt += "\n\(orientationPromptGuidelines())\n"

        // Add life area priorities
        let topAreas = profile.topLifeAreas(count: 3)
        if !topAreas.isEmpty {
            prompt += "TOP PRIORITIES: \(topAreas.map { $0.rawValue }.joined(separator: ", "))\n"
        }

        // Add legacy values if available
        let coreValues = profile.topValues(count: 3)
        if !coreValues.isEmpty {
            prompt += "VALUES: \(coreValues.map { $0.rawValue }.joined(separator: ", "))\n"
        }

        // Add communication style
        prompt += "STYLE: \(profile.tone.aiPromptGuideline)\n"
        prompt += "LENGTH: \(profile.verbosity.description)\n"

        // Add memory context
        let memoryContext = memoryService.buildMemoryContext(from: profile)
        if !memoryContext.isEmpty {
            prompt += "\n\(memoryContext)\n"
        }

        // Add personalization guidance based on orientation
        prompt += """

        GUIDELINES:
        - Respond in \(profile.verbosity.maxSentences) sentences or fewer unless more detail is needed
        - Reference their top priorities (\(topAreas.map { $0.rawValue }.joined(separator: ", "))) when suggesting what to focus on
        - Adapt to their orientation type (\(orientationType.rawValue)) - see guidelines above
        - Remember past conversations and build on them
        - Be \(profile.tone.rawValue) in your responses
        - Focus on actionable suggestions over general advice
        """

        return prompt
    }

    private var defaultSystemPrompt: String {
        """
        You are a gentle, reliable companion in the Spheres productivity app.
        You help users manage their life across different spheres (areas of focus).
        Be warm, encouraging, and concise. Focus on actionable suggestions.
        """
    }

    // MARK: - Values-Based Prioritization

    /// Calculates a priority boost for a task based on alignment with user values
    func valueAlignmentBoost(for sphere: SphereModel) -> Double {
        guard let profile = currentProfile else { return 1.0 }

        let sphereName = sphere.name.lowercased()
        var boost = 1.0

        // Check if sphere aligns with user's core values
        for value in profile.topValues(count: 5) {
            let suggestedSpheres = value.suggestedSpheres.map { $0.lowercased() }
            if suggestedSpheres.contains(where: { sphereName.contains($0) || $0.contains(sphereName) }) {
                boost *= 1.2  // 20% boost per matching value
            }
        }

        // Check sphere priorities
        if let rank = profile.spherePriorities[sphere.id] {
            // Rank 1 = highest priority, boost more
            boost *= (1.0 + Double(6 - rank) / 10.0)
        }

        return min(boost, 2.0)  // Cap at 2x boost
    }

    /// Sorts loops by value-weighted priority
    func sortByValuePriority(_ loops: [OpenLoopModel]) -> [OpenLoopModel] {
        return loops.sorted { a, b in
            let aBoost = a.sphere.map { valueAlignmentBoost(for: $0) } ?? 1.0
            let bBoost = b.sphere.map { valueAlignmentBoost(for: $0) } ?? 1.0

            let aPriority = Double(6 - a.importance) * aBoost
            let bPriority = Double(6 - b.importance) * bBoost

            return aPriority > bPriority
        }
    }

    // MARK: - Sphere Suggestions (All 7 areas, priority ordered)

    /// Returns ALL 7 life areas as spheres, ordered by user's priority
    /// Everyone gets the same spheres, but in personalized priority order
    func allSpheresWithPriority() -> [(area: LifeArea, priority: Int)] {
        guard let profile = currentProfile else {
            // Default order if no profile
            return LifeArea.allCases.enumerated().map { ($0.element, $0.offset + 1) }
        }

        // Get prioritized areas from orientation profile
        let prioritizedAreas = profile.prioritizedLifeAreas()

        return prioritizedAreas.enumerated().map { (index, area) in
            (area: area, priority: index + 1)
        }
    }

    /// Suggests spheres based on user's values from the quiz (legacy support)
    func suggestedSpheres() -> [(name: String, icon: String, color: SchwartzValue)] {
        guard let profile = currentProfile else { return [] }

        var suggestions: [(name: String, icon: String, color: SchwartzValue)] = []
        var addedNames: Set<String> = []

        for value in profile.topValues(count: 5) {
            for sphereName in value.suggestedSpheres {
                if !addedNames.contains(sphereName) {
                    addedNames.insert(sphereName)
                    let icon = sphereIcon(for: sphereName)
                    suggestions.append((name: sphereName, icon: icon, color: value))
                }
            }
        }

        return Array(suggestions.prefix(8))  // Return top 8 suggestions
    }

    // MARK: - Orientation-Based Personalization

    /// Get the user's orientation profile
    var orientationProfile: LifeOrientationProfile? {
        return currentProfile?.orientationProfile
    }

    /// Get the user's primary orientation type
    var orientationType: LifeOrientationType? {
        return orientationProfile?.primaryType
    }

    /// Build AI prompt additions based on orientation type
    func orientationPromptGuidelines() -> String {
        guard let type = orientationType else { return "" }

        switch type {
        case .contemplative:
            return """
            USER TYPE: Contemplative
            - Values depth over breadth
            - Appreciates reflection and meaning
            - May need encouragement to take action
            - Speak thoughtfully, allow space for processing
            """
        case .activist:
            return """
            USER TYPE: Activist
            - Values action and tangible results
            - Energized by making a difference
            - May need reminders for self-care
            - Be direct and action-oriented
            """
        case .relational:
            return """
            USER TYPE: Relational
            - Values deep connections
            - Decisions often consider others
            - May need help with boundaries
            - Acknowledge the people in their life
            """
        case .visionary:
            return """
            USER TYPE: Visionary
            - Thinks big picture and long-term
            - Motivated by impact and legacy
            - May need help with immediate tasks
            - Connect tasks to larger purpose
            """
        case .steward:
            return """
            USER TYPE: Steward
            - Values responsibility and reliability
            - Focused on providing and protecting
            - May carry too much burden
            - Acknowledge their faithfulness
            """
        case .seeker:
            return """
            USER TYPE: Seeker
            - Values growth and understanding
            - Curious about meaning
            - May get lost in learning vs doing
            - Offer insights and deeper connections
            """
        case .balanced:
            return """
            USER TYPE: Balanced
            - Integrates multiple perspectives
            - Adaptable approach
            - May struggle with extremes
            - Support their holistic view
            """
        }
    }

    private func sphereIcon(for name: String) -> String {
        switch name.lowercased() {
        case "health": return "heart.fill"
        case "career": return "briefcase.fill"
        case "family": return "figure.2.and.child.holdinghands"
        case "education": return "book.fill"
        case "creative": return "paintbrush.fill"
        case "spirituality", "spiritual": return "sparkles"
        case "finances": return "dollarsign.circle.fill"
        case "relationships": return "person.2.fill"
        case "personal growth", "growth": return "arrow.up.circle.fill"
        case "adventure": return "airplane"
        case "fun", "fun/recreation": return "gamecontroller.fill"
        case "community": return "globe.americas.fill"
        case "environment": return "leaf.fill"
        case "self-care": return "heart.circle.fill"
        case "hobbies": return "star.fill"
        case "travel": return "map.fill"
        case "leadership": return "crown.fill"
        case "culture": return "building.columns.fill"
        case "caregiving": return "hand.raised.fill"
        case "social impact", "purpose": return "hands.sparkles.fill"
        default: return "circle.fill"
        }
    }

    // MARK: - Feedback & Learning

    /// Records when user accepts or rejects a suggestion
    func recordFeedback(suggestionType: String, accepted: Bool, feedback: String? = nil) {
        currentProfile?.recordFeedback(
            suggestionType: suggestionType,
            wasAccepted: accepted,
            feedback: feedback
        )
    }

    /// Records a user interaction (for personalization depth tracking)
    func recordInteraction() {
        currentProfile?.recordInteraction()
    }

    // MARK: - Memory Passthrough

    /// Stores a memory about the user
    func remember(_ content: String, category: MemoryCategory, priority: MemoryPriority) {
        guard let profile = currentProfile else { return }
        memoryService.remember(content, category: category, priority: priority, profile: profile)
    }

    /// Extracts and stores memories from a conversation message
    func processMessage(_ message: String) {
        guard let profile = currentProfile else { return }
        memoryService.extractAndStoreMemories(from: message, profile: profile)
        recordInteraction()
    }

    /// Seeds memories from onboarding
    func seedFromOnboarding(name: String?, coreValues: [SchwartzValue], style: CommunicationTone) {
        guard let profile = currentProfile else { return }
        memoryService.seedFromOnboarding(
            name: name,
            coreValues: coreValues,
            communicationStyle: style,
            profile: profile
        )
    }

    /// Performs memory maintenance (call periodically)
    func performMaintenance() {
        guard let profile = currentProfile else { return }
        memoryService.performMaintenance(on: profile)
    }
}

// MARK: - PersonalizationDepth Extension

extension PersonalizationDepth: RawRepresentable {
    typealias RawValue = Int

    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .minimal
        case 1: self = .moderate
        case 2: self = .deep
        case 3: self = .complete
        default: return nil
        }
    }

    var rawValue: Int {
        switch self {
        case .minimal: return 0
        case .moderate: return 1
        case .deep: return 2
        case .complete: return 3
        }
    }
}
