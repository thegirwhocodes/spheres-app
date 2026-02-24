//
//  UserProfileModel.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Values-based user profiling using Schwartz Theory
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Life Orientations Model (Biblical + Psychology Foundation)

/// A psychological model for understanding life priorities, grounded in biblical wisdom.
///
/// **Research Basis:**
/// - Schwartz Theory of Basic Values (structural approach with tensions)
/// - Harvard Human Flourishing Program (Tyler VanderWeele)
/// - Time Perspective Theory (Zimbardo)
/// - Self-Determination Theory (Ryan & Deci)
///
/// **Biblical Basis:**
/// - Martha vs Mary tension (Luke 10:38-42) → Doing ↔ Being
/// - Work vs Trust (Prov 10:4 + Matt 6:25-34) → Provision ↔ Faith
/// - Family vs Mission (1 Tim 5:8 + Luke 14:26) → Inner circle ↔ Wider impact
/// - Body as temple (1 Cor 6:19) + Self-denial (Luke 9:23) → Self-care ↔ Sacrifice
///
/// **The 4 Dimensions (each is a spectrum):**
/// 1. Renewal Source: Solitude ↔ Community
/// 2. Expression Mode: Being/Devotion ↔ Doing/Action
/// 3. Care Focus: Inner Circle (self/family) ↔ Outer Circle (mission/world)
/// 4. Time Horizon: Present (immediate needs) ↔ Future (long-term/eternal)

struct LifeOrientationProfile: Codable, Equatable {
    /// Solitude ↔ Community (0.0 = pure solitude, 1.0 = pure community)
    var renewalSource: Double = 0.5

    /// Being ↔ Doing (0.0 = contemplative, 1.0 = active)
    var expressionMode: Double = 0.5

    /// Inner Circle ↔ Outer Circle (0.0 = self/family focused, 1.0 = mission/world focused)
    var careFocus: Double = 0.5

    /// Present ↔ Future (0.0 = present-focused, 1.0 = future/eternal focused)
    var timeHorizon: Double = 0.5

    /// Derives a "type" name based on the dominant orientation
    var primaryType: LifeOrientationType {
        // Find dominant dimension
        let dimensions: [(String, Double)] = [
            ("solitude", 1.0 - renewalSource),
            ("community", renewalSource),
            ("being", 1.0 - expressionMode),
            ("doing", expressionMode),
            ("inner", 1.0 - careFocus),
            ("outer", careFocus),
            ("present", 1.0 - timeHorizon),
            ("future", timeHorizon)
        ]

        let sorted = dimensions.sorted { $0.1 > $1.1 }
        let top1 = sorted[0].0
        let top2 = sorted[1].0

        // Map combinations to types
        switch (top1, top2) {
        case ("solitude", "being"), ("being", "solitude"):
            return .contemplative
        case ("doing", "outer"), ("outer", "doing"):
            return .activist
        case ("community", "inner"), ("inner", "community"):
            return .relational
        case ("outer", "future"), ("future", "outer"):
            return .visionary
        case ("doing", "inner"), ("inner", "doing"):
            return .steward
        case ("being", "future"), ("future", "being"):
            return .seeker
        default:
            return .balanced
        }
    }
}

/// Archetypes that emerge from the orientation profile
enum LifeOrientationType: String, Codable, CaseIterable {
    case contemplative = "Contemplative"  // Solitude + Being - drawn to prayer, reflection
    case activist = "Activist"            // Community + Doing - drawn to service, action
    case relational = "Relational"        // Community + Inner - drawn to family, deep relationships
    case visionary = "Visionary"          // Outer + Future - drawn to mission, big picture
    case steward = "Steward"              // Doing + Inner - drawn to responsibility, providing
    case seeker = "Seeker"                // Being + Future - drawn to growth, wisdom, meaning
    case balanced = "Balanced"            // No dominant pattern

    var description: String {
        switch self {
        case .contemplative: return "You find renewal in quiet reflection and spiritual depth"
        case .activist: return "You're energized by making a tangible difference in the world"
        case .relational: return "Your deepest fulfillment comes from close relationships"
        case .visionary: return "You're drawn to the bigger picture and lasting impact"
        case .steward: return "You find meaning in faithful responsibility and provision"
        case .seeker: return "You're on a journey of growth and understanding"
        case .balanced: return "You integrate multiple dimensions naturally"
        }
    }

    var icon: String {
        switch self {
        case .contemplative: return "sparkles"
        case .activist: return "hands.sparkles.fill"
        case .relational: return "heart.fill"
        case .visionary: return "eye.fill"
        case .steward: return "shield.fill"
        case .seeker: return "book.fill"
        case .balanced: return "circle.grid.cross.fill"
        }
    }
}

// MARK: - Life Areas (Biblical Foundation)

/// The 7 core life areas - everyone gets all of these, but in different priority order
/// Based on biblical principles of stewardship and wholeness
enum LifeArea: String, Codable, CaseIterable {
    case faith = "Faith"
    case family = "Family"
    case health = "Health"
    case work = "Work"
    case finances = "Finances"
    case community = "Community"
    case growth = "Growth"

    var description: String {
        switch self {
        case .faith: return "Spiritual life, purpose, and inner peace"
        case .family: return "Relationships with loved ones"
        case .health: return "Physical and mental wellbeing"
        case .work: return "Career, calling, and meaningful work"
        case .finances: return "Stewardship and financial health"
        case .community: return "Serving others and connection"
        case .growth: return "Learning, creativity, and personal development"
        }
    }

    var icon: String {
        switch self {
        case .faith: return "sparkles"
        case .family: return "figure.2.and.child.holdinghands"
        case .health: return "heart.fill"
        case .work: return "briefcase.fill"
        case .finances: return "dollarsign.circle.fill"
        case .community: return "person.3.fill"
        case .growth: return "arrow.up.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .faith: return .purple
        case .family: return .pink
        case .health: return .green
        case .work: return .blue
        case .finances: return .yellow
        case .community: return .orange
        case .growth: return .cyan
        }
    }

    /// Default sphere name for this life area
    var sphereName: String {
        switch self {
        case .faith: return "Spiritual"
        case .family: return "Family"
        case .health: return "Health"
        case .work: return "Career"
        case .finances: return "Finances"
        case .community: return "Community"
        case .growth: return "Growth"
        }
    }

    /// How much this life area is boosted by each orientation dimension
    /// Used to calculate personalized priority order
    var orientationWeights: (renewal: Double, expression: Double, care: Double, time: Double) {
        switch self {
        case .faith:
            // Boosted by: solitude (low renewal), being (low expression), future (high time)
            return (renewal: -0.3, expression: -0.4, care: 0.0, time: 0.3)
        case .family:
            // Boosted by: community (high renewal), inner circle (low care)
            return (renewal: 0.3, expression: 0.0, care: -0.5, time: 0.0)
        case .health:
            // Boosted by: present focus (low time), being (low expression)
            return (renewal: 0.0, expression: -0.2, care: -0.2, time: -0.3)
        case .work:
            // Boosted by: doing (high expression), stewardship (inner care)
            return (renewal: 0.0, expression: 0.5, care: -0.2, time: 0.2)
        case .finances:
            // Boosted by: doing, inner circle, future
            return (renewal: -0.1, expression: 0.3, care: -0.3, time: 0.4)
        case .community:
            // Boosted by: community (high renewal), outer circle (high care), doing
            return (renewal: 0.4, expression: 0.3, care: 0.5, time: 0.0)
        case .growth:
            // Boosted by: being, solitude, future
            return (renewal: -0.2, expression: -0.2, care: 0.0, time: 0.3)
        }
    }

    /// Calculate priority score for this area based on orientation profile
    func priorityScore(for profile: LifeOrientationProfile) -> Double {
        let w = orientationWeights
        var score = 0.5  // Baseline

        // Each dimension contributes based on its weight
        score += w.renewal * (profile.renewalSource - 0.5)
        score += w.expression * (profile.expressionMode - 0.5)
        score += w.care * (profile.careFocus - 0.5)
        score += w.time * (profile.timeHorizon - 0.5)

        return max(0.1, min(1.0, score))
    }
}

// MARK: - Schwartz Basic Human Values (Legacy - kept for compatibility)

/// The 10 basic human values from Schwartz Theory (most validated in psychology)
enum SchwartzValue: String, Codable, CaseIterable {
    case selfDirection = "Self-Direction"
    case stimulation = "Stimulation"
    case hedonism = "Hedonism"
    case achievement = "Achievement"
    case power = "Power"
    case security = "Security"
    case conformity = "Conformity"
    case tradition = "Tradition"
    case benevolence = "Benevolence"
    case universalism = "Universalism"

    var description: String {
        switch self {
        case .selfDirection: return "Freedom, creativity, curiosity, independence"
        case .stimulation: return "Excitement, novelty, challenge in life"
        case .hedonism: return "Pleasure, enjoying life, self-indulgence"
        case .achievement: return "Personal success, competence, ambition"
        case .power: return "Status, prestige, control over resources"
        case .security: return "Safety, stability, health, family security"
        case .conformity: return "Self-discipline, politeness, honoring expectations"
        case .tradition: return "Respect, humility, devotion, accepting customs"
        case .benevolence: return "Loyalty, honesty, helpfulness to close others"
        case .universalism: return "Equality, justice, protecting people and nature"
        }
    }

    var icon: String {
        switch self {
        case .selfDirection: return "lightbulb.fill"
        case .stimulation: return "bolt.fill"
        case .hedonism: return "face.smiling.fill"
        case .achievement: return "trophy.fill"
        case .power: return "crown.fill"
        case .security: return "shield.fill"
        case .conformity: return "person.2.fill"
        case .tradition: return "book.closed.fill"
        case .benevolence: return "heart.fill"
        case .universalism: return "globe.americas.fill"
        }
    }

    var color: Color {
        switch self {
        case .selfDirection: return .orange
        case .stimulation: return .red
        case .hedonism: return .pink
        case .achievement: return .yellow
        case .power: return .purple
        case .security: return .blue
        case .conformity: return .teal
        case .tradition: return .brown
        case .benevolence: return .green
        case .universalism: return .cyan
        }
    }

    /// Maps value to suggested sphere categories
    var suggestedSpheres: [String] {
        switch self {
        case .selfDirection: return ["Personal Growth", "Creative", "Education"]
        case .stimulation: return ["Adventure", "Fun", "Travel"]
        case .hedonism: return ["Fun/Recreation", "Self-Care", "Hobbies"]
        case .achievement: return ["Career", "Education", "Goals"]
        case .power: return ["Career", "Finances", "Leadership"]
        case .security: return ["Health", "Finances", "Family"]
        case .conformity: return ["Relationships", "Work", "Community"]
        case .tradition: return ["Spirituality", "Family", "Culture"]
        case .benevolence: return ["Family", "Relationships", "Caregiving"]
        case .universalism: return ["Community", "Environment", "Social Impact"]
        }
    }

    /// Dimension 1: Openness to Change vs Conservation
    var opennessScore: Double {
        switch self {
        case .selfDirection, .stimulation: return 1.0
        case .hedonism: return 0.5
        case .security, .conformity, .tradition: return 0.0
        default: return 0.5
        }
    }

    /// Dimension 2: Self-Enhancement vs Self-Transcendence
    var selfTranscendenceScore: Double {
        switch self {
        case .benevolence, .universalism: return 1.0
        case .tradition, .conformity: return 0.7
        case .achievement, .power: return 0.0
        case .hedonism: return 0.3
        default: return 0.5
        }
    }
}

// MARK: - Communication Preferences

enum CommunicationTone: String, Codable, CaseIterable {
    case supportive = "supportive"
    case direct = "direct"
    case playful = "playful"
    case professional = "professional"

    var description: String {
        switch self {
        case .supportive: return "Warm, encouraging, and empathetic"
        case .direct: return "Brief, clear, and to the point"
        case .playful: return "Upbeat, fun, with light humor"
        case .professional: return "Formal, efficient, and businesslike"
        }
    }

    var aiPromptGuideline: String {
        switch self {
        case .supportive: return "Be warm, encouraging, and supportive. Use gentle language."
        case .direct: return "Be brief and direct. Skip pleasantries. Get to the point."
        case .playful: return "Be upbeat and fun. Light humor is welcome."
        case .professional: return "Be clear, efficient, and professional."
        }
    }
}

enum VerbosityLevel: String, Codable, CaseIterable {
    case minimal = "minimal"
    case concise = "concise"
    case detailed = "detailed"

    var description: String {
        switch self {
        case .minimal: return "One-liners only"
        case .concise: return "2-3 sentences"
        case .detailed: return "Full explanations"
        }
    }

    var maxSentences: Int {
        switch self {
        case .minimal: return 1
        case .concise: return 3
        case .detailed: return 10
        }
    }
}

// MARK: - Memory Models

enum MemoryCategory: String, Codable, CaseIterable {
    case identity       // Name, pronouns
    case values         // Core values from quiz
    case preferences    // Communication style, UI choices
    case goals          // Life goals, current focus
    case patterns       // Learned behaviors
    case context        // Current projects, recent topics
    case corrections    // "Actually, I prefer X over Y"
}

enum MemoryPriority: Int, Codable, CaseIterable {
    case critical = 5   // Never forget: name, core values
    case high = 4       // Keep long-term: goals, hard preferences
    case medium = 3     // Summarize over time: recent context
    case low = 2        // Compress aggressively: routine stuff
    case ephemeral = 1  // Delete after session
}

struct MemoryItem: Codable, Identifiable {
    let id: UUID
    var content: String
    var category: MemoryCategory
    var priority: MemoryPriority
    var createdAt: Date
    var lastAccessed: Date
    var accessCount: Int

    init(content: String, category: MemoryCategory, priority: MemoryPriority) {
        self.id = UUID()
        self.content = content
        self.category = category
        self.priority = priority
        self.createdAt = Date()
        self.lastAccessed = Date()
        self.accessCount = 0
    }
}

struct FeedbackEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let suggestionType: String
    let wasAccepted: Bool
    let userFeedback: String?

    init(suggestionType: String, wasAccepted: Bool, userFeedback: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.suggestionType = suggestionType
        self.wasAccepted = wasAccepted
        self.userFeedback = userFeedback
    }
}

// MARK: - User Profile Model

@Model
final class UserProfileModel {
    var id: UUID = UUID()

    // === IDENTITY ===
    var displayName: String = ""
    var preferredPronouns: String = ""

    // === VALUES (from quiz) ===
    /// Top 3-5 core values identified from quiz
    var coreValuesData: Data?

    /// All 10 Schwartz values with scores (0.0-1.0)
    var valuesScoresData: Data?

    // === LIFE ORIENTATIONS (from priority quiz) ===
    /// The 4-dimensional orientation profile
    var orientationProfileData: Data?

    /// All 7 life areas with priority scores (0.0-1.0)
    var lifeAreaScoresData: Data?

    /// User's custom answers from quiz "Other" fields
    var customQuizAnswersData: Data?

    // === COMMUNICATION PREFERENCES ===
    var preferredTone: String = CommunicationTone.supportive.rawValue
    var verbosityLevel: String = VerbosityLevel.concise.rawValue

    // === BEHAVIORAL PATTERNS (learned over time) ===
    var averageTasksPerDay: Double = 0.0
    var peakProductivityHoursData: Data?  // Encoded [Int]
    var taskCompletionPatternsData: Data?  // Encoded [String: Double]

    // === SCHEDULING PREFERENCES ===
    var spherePrioritiesData: Data?  // Encoded [String: Int] (Sphere ID string → rank)
    var preferredDeepWorkDuration: Int = 90

    // === LEARNING DATA ===
    var interactionCount: Int = 0
    var suggestionAcceptanceRate: Double = 0.5
    var feedbackHistoryData: Data?  // Encoded [FeedbackEntry]

    // === MEMORY ===
    var rememberedFactsData: Data?  // Encoded [MemoryItem]

    // === TIMESTAMPS ===
    var createdDate: Date = Date()
    var lastUpdated: Date = Date()
    var lastActiveDate: Date = Date()

    // MARK: - Computed Properties

    var coreValues: [SchwartzValue] {
        get {
            guard let data = coreValuesData,
                  let values = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return values.compactMap { SchwartzValue(rawValue: $0) }
        }
        set {
            coreValuesData = try? JSONEncoder().encode(newValue.map { $0.rawValue })
        }
    }

    var valuesScores: [SchwartzValue: Double] {
        get {
            guard let data = valuesScoresData,
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            var result: [SchwartzValue: Double] = [:]
            for (key, value) in dict {
                if let schwartzValue = SchwartzValue(rawValue: key) {
                    result[schwartzValue] = value
                }
            }
            return result
        }
        set {
            let dict = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
            valuesScoresData = try? JSONEncoder().encode(dict)
        }
    }

    var orientationProfile: LifeOrientationProfile {
        get {
            guard let data = orientationProfileData,
                  let profile = try? JSONDecoder().decode(LifeOrientationProfile.self, from: data) else {
                return LifeOrientationProfile()
            }
            return profile
        }
        set {
            orientationProfileData = try? JSONEncoder().encode(newValue)
        }
    }

    var lifeAreaScores: [LifeArea: Double] {
        get {
            guard let data = lifeAreaScoresData,
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            var result: [LifeArea: Double] = [:]
            for (key, value) in dict {
                if let area = LifeArea(rawValue: key) {
                    result[area] = value
                }
            }
            return result
        }
        set {
            let dict = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
            lifeAreaScoresData = try? JSONEncoder().encode(dict)
        }
    }

    /// Calculate life area priorities based on orientation profile
    func calculateLifeAreaPriorities() -> [LifeArea: Double] {
        let profile = orientationProfile
        var priorities: [LifeArea: Double] = [:]
        for area in LifeArea.allCases {
            priorities[area] = area.priorityScore(for: profile)
        }
        return priorities
    }

    var customQuizAnswers: [String] {
        get {
            guard let data = customQuizAnswersData,
                  let answers = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return answers
        }
        set {
            customQuizAnswersData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Returns life areas sorted by priority (highest score first)
    func prioritizedLifeAreas() -> [LifeArea] {
        let scores = lifeAreaScores
        if scores.isEmpty {
            // Default order if no quiz completed
            return LifeArea.allCases
        }
        return scores.sorted { $0.value > $1.value }.map { $0.key }
    }

    /// Get the top N life areas by priority
    func topLifeAreas(count: Int = 3) -> [LifeArea] {
        return Array(prioritizedLifeAreas().prefix(count))
    }

    var tone: CommunicationTone {
        get { CommunicationTone(rawValue: preferredTone) ?? .supportive }
        set { preferredTone = newValue.rawValue }
    }

    var verbosity: VerbosityLevel {
        get { VerbosityLevel(rawValue: verbosityLevel) ?? .concise }
        set { verbosityLevel = newValue.rawValue }
    }

    var peakProductivityHours: [Int] {
        get {
            guard let data = peakProductivityHoursData,
                  let hours = try? JSONDecoder().decode([Int].self, from: data) else {
                return []
            }
            return hours
        }
        set {
            peakProductivityHoursData = try? JSONEncoder().encode(newValue)
        }
    }

    var spherePriorities: [UUID: Int] {
        get {
            guard let data = spherePrioritiesData,
                  let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
                return [:]
            }
            var result: [UUID: Int] = [:]
            for (key, value) in dict {
                if let uuid = UUID(uuidString: key) {
                    result[uuid] = value
                }
            }
            return result
        }
        set {
            let dict = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.uuidString, $0.value) })
            spherePrioritiesData = try? JSONEncoder().encode(dict)
        }
    }

    var rememberedFacts: [MemoryItem] {
        get {
            guard let data = rememberedFactsData,
                  let items = try? JSONDecoder().decode([MemoryItem].self, from: data) else {
                return []
            }
            return items
        }
        set {
            rememberedFactsData = try? JSONEncoder().encode(newValue)
        }
    }

    var feedbackHistory: [FeedbackEntry] {
        get {
            guard let data = feedbackHistoryData,
                  let entries = try? JSONDecoder().decode([FeedbackEntry].self, from: data) else {
                return []
            }
            return entries
        }
        set {
            feedbackHistoryData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Initialization

    init() {
        self.id = UUID()
        self.createdDate = Date()
        self.lastUpdated = Date()
        self.lastActiveDate = Date()
    }

    // MARK: - Helper Methods

    /// Get the top N core values sorted by score
    func topValues(count: Int = 3) -> [SchwartzValue] {
        let sorted = valuesScores.sorted { $0.value > $1.value }
        return Array(sorted.prefix(count).map { $0.key })
    }

    /// Check if user values a particular thing highly
    func values(_ value: SchwartzValue, threshold: Double = 0.7) -> Bool {
        return (valuesScores[value] ?? 0) >= threshold
    }

    /// Get suggested spheres based on top values
    func suggestedSphereNames() -> [String] {
        var suggestions: [String: Int] = [:]  // sphere name -> count of supporting values

        for value in topValues(count: 5) {
            for sphere in value.suggestedSpheres {
                suggestions[sphere, default: 0] += 1
            }
        }

        // Return top suggestions, sorted by how many values support them
        return suggestions.sorted { $0.value > $1.value }.map { $0.key }
    }

    /// Record a new interaction
    func recordInteraction() {
        interactionCount += 1
        lastActiveDate = Date()
        lastUpdated = Date()
    }

    /// Record feedback on a suggestion
    func recordFeedback(suggestionType: String, wasAccepted: Bool, feedback: String? = nil) {
        var history = feedbackHistory
        history.append(FeedbackEntry(suggestionType: suggestionType, wasAccepted: wasAccepted, userFeedback: feedback))
        feedbackHistory = history

        // Update acceptance rate
        let recentFeedback = history.suffix(50)  // Last 50 suggestions
        let acceptedCount = recentFeedback.filter { $0.wasAccepted }.count
        suggestionAcceptanceRate = Double(acceptedCount) / Double(recentFeedback.count)

        lastUpdated = Date()
    }
}

// MARK: - Profile Personalization Level

enum PersonalizationDepth {
    case minimal    // "Good morning"
    case moderate   // "Good morning, Sarah"
    case deep       // "Good morning, Sarah. You have 3 high-priority items..."
    case complete   // "Sarah, I noticed you usually tackle deep work first. Ready?"

    static func forInteractionCount(_ count: Int) -> PersonalizationDepth {
        switch count {
        case 0..<10: return .minimal
        case 10..<50: return .moderate
        case 50..<200: return .deep
        default: return .complete
        }
    }
}
