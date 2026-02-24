//
//  AdaptiveProfileService.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Spotify-inspired adaptive profile evolution algorithm
//

import Foundation
import SwiftData

// MARK: - Adaptive Profile Service

/// A premium adaptive algorithm that evolves user profiles over time based on implicit behavior signals.
///
/// **Inspired by:**
/// - Spotify's recommendation system (collaborative filtering + reinforcement learning)
/// - Implicit feedback systems (ALS algorithm for preference inference)
/// - Behavioral biometrics (sequential pattern detection)
///
/// **Key Principles:**
/// 1. **Implicit > Explicit**: Actions speak louder than survey answers
/// 2. **Time Decay**: Recent behavior matters more than old behavior
/// 3. **Small Adjustments**: Gradual evolution prevents wild swings (±0.05 max)
/// 4. **Confidence Scoring**: Need sufficient data before making changes
/// 5. **Pattern Detection**: Discover weekly/seasonal rhythms
@MainActor
class AdaptiveProfileService: ObservableObject {
    static let shared = AdaptiveProfileService()

    // MARK: - Configuration

    /// Minimum events needed before making adjustments
    private let minimumEventsForAdjustment = 20

    /// Maximum adjustment per dimension per cycle (prevents wild swings)
    private let maxAdjustmentPerCycle: Double = 0.05

    /// Time decay half-life in days (behavior from 14 days ago = 50% weight)
    private let decayHalfLifeDays: Double = 14.0

    /// Confidence threshold for making adjustments (0.0-1.0)
    private let confidenceThreshold: Double = 0.6

    /// How often to run the adaptation algorithm (in seconds)
    private let adaptationInterval: TimeInterval = 3600 // 1 hour

    // MARK: - State

    @Published var lastAdaptationDate: Date?
    @Published var adaptationConfidence: Double = 0.0
    @Published var pendingAdjustments: [String: Double] = [:]

    private var behaviorBuffer: [BehaviorEvent] = []

    private init() {
        loadBehaviorBuffer()
    }

    // MARK: - Behavior Event Tracking

    /// Track a user behavior event
    func trackEvent(_ event: BehaviorEvent) {
        behaviorBuffer.append(event)
        saveBehaviorBuffer()

        // Check if we should run adaptation
        if shouldRunAdaptation() {
            Task {
                await runAdaptation()
            }
        }
    }

    /// Convenience method: track task completion
    func trackTaskCompletion(sphereId: UUID, lifeArea: LifeArea?, duration: TimeInterval, wasOnTime: Bool) {
        trackEvent(BehaviorEvent(
            type: .taskCompleted,
            lifeArea: lifeArea,
            sphereId: sphereId,
            metadata: [
                "duration": duration,
                "onTime": wasOnTime
            ]
        ))
    }

    /// Convenience method: track task skip/defer
    func trackTaskSkip(sphereId: UUID, lifeArea: LifeArea?, reason: SkipReason) {
        trackEvent(BehaviorEvent(
            type: .taskSkipped,
            lifeArea: lifeArea,
            sphereId: sphereId,
            metadata: ["reason": reason.rawValue]
        ))
    }

    /// Convenience method: track time spent in sphere view
    func trackSphereEngagement(sphereId: UUID, lifeArea: LifeArea?, duration: TimeInterval) {
        // Only track if meaningful engagement (> 10 seconds)
        guard duration > 10 else { return }

        trackEvent(BehaviorEvent(
            type: .sphereViewed,
            lifeArea: lifeArea,
            sphereId: sphereId,
            metadata: ["duration": duration]
        ))
    }

    /// Convenience method: track suggestion acceptance
    func trackSuggestionAccepted(type: SuggestionType, lifeArea: LifeArea?) {
        trackEvent(BehaviorEvent(
            type: .suggestionAccepted,
            lifeArea: lifeArea,
            metadata: ["suggestionType": type.rawValue]
        ))
    }

    /// Convenience method: track suggestion rejection
    func trackSuggestionRejected(type: SuggestionType, lifeArea: LifeArea?) {
        trackEvent(BehaviorEvent(
            type: .suggestionRejected,
            lifeArea: lifeArea,
            metadata: ["suggestionType": type.rawValue]
        ))
    }

    /// Convenience method: track sphere creation
    func trackSphereCreated(sphereId: UUID, lifeArea: LifeArea?) {
        trackEvent(BehaviorEvent(
            type: .sphereCreated,
            lifeArea: lifeArea,
            sphereId: sphereId
        ))
    }

    /// Convenience method: track energy level selection
    func trackEnergyTimeSelection(hour: Int, taskCategory: String) {
        trackEvent(BehaviorEvent(
            type: .energyTimeSelected,
            metadata: [
                "hour": hour,
                "taskCategory": taskCategory
            ]
        ))
    }

    // MARK: - Adaptation Algorithm

    private func shouldRunAdaptation() -> Bool {
        guard behaviorBuffer.count >= minimumEventsForAdjustment else { return false }

        if let lastDate = lastAdaptationDate {
            return Date().timeIntervalSince(lastDate) > adaptationInterval
        }

        return true
    }

    /// Main adaptation algorithm - analyzes behavior and adjusts profile
    func runAdaptation() async {
        guard let profile = PersonalizationService.shared.currentProfile else { return }

        // Get current orientation
        var orientation = profile.orientationProfile

        // Calculate adjustments based on behavioral signals
        let signals = analyzeImplicitSignals()

        // Calculate confidence in the adjustments
        let confidence = calculateConfidence(from: signals)
        adaptationConfidence = confidence

        guard confidence >= confidenceThreshold else {
            // Not enough confidence yet - keep collecting data
            return
        }

        // Apply adjustments with time decay weighting
        let adjustments = calculateAdjustments(from: signals, currentOrientation: orientation)
        pendingAdjustments = adjustments.mapValues { String(format: "%.3f", $0) }.reduce(into: [:]) { $0[$1.key] = Double($1.value) ?? 0 }

        // Apply bounded adjustments
        orientation.renewalSource = clamp(orientation.renewalSource + (adjustments["renewal"] ?? 0))
        orientation.expressionMode = clamp(orientation.expressionMode + (adjustments["expression"] ?? 0))
        orientation.careFocus = clamp(orientation.careFocus + (adjustments["care"] ?? 0))
        orientation.timeHorizon = clamp(orientation.timeHorizon + (adjustments["time"] ?? 0))

        // Update profile
        profile.orientationProfile = orientation
        profile.lifeAreaScores = profile.calculateLifeAreaPriorities()
        profile.lastUpdated = Date()

        // Update state
        lastAdaptationDate = Date()

        // Clear old events (keep last 30 days)
        pruneOldEvents()

        // Save profile context will handle persistence
    }

    // MARK: - Signal Analysis

    /// Analyze implicit behavioral signals from event history
    private func analyzeImplicitSignals() -> BehaviorSignals {
        let now = Date()
        var signals = BehaviorSignals()

        // Group events by life area with time decay weighting
        var areaEngagement: [LifeArea: Double] = [:]
        var areaCompletions: [LifeArea: Double] = [:]
        var areaSkips: [LifeArea: Double] = [:]
        var suggestionAcceptances: Double = 0
        var suggestionRejections: Double = 0

        for event in behaviorBuffer {
            let weight = calculateTimeDecayWeight(eventDate: event.timestamp, now: now)

            switch event.type {
            case .taskCompleted:
                if let area = event.lifeArea {
                    areaCompletions[area, default: 0] += weight

                    // Bonus weight for on-time completion
                    if let onTime = event.metadata["onTime"] as? Bool, onTime {
                        areaCompletions[area, default: 0] += weight * 0.5
                    }
                }

            case .taskSkipped:
                if let area = event.lifeArea {
                    areaSkips[area, default: 0] += weight
                }

            case .sphereViewed:
                if let area = event.lifeArea {
                    // Weight by duration (logarithmic to prevent gaming)
                    let duration = event.metadata["duration"] as? TimeInterval ?? 0
                    let durationWeight = log10(max(1, duration / 60)) // minutes, log scale
                    areaEngagement[area, default: 0] += weight * durationWeight
                }

            case .sphereCreated:
                if let area = event.lifeArea {
                    // Strong signal - user actively created this
                    areaEngagement[area, default: 0] += weight * 3.0
                }

            case .suggestionAccepted:
                suggestionAcceptances += weight
                if let area = event.lifeArea {
                    areaEngagement[area, default: 0] += weight * 1.5
                }

            case .suggestionRejected:
                suggestionRejections += weight

            case .energyTimeSelected, .loopPrioritized:
                // These help with energy intelligence, not orientation
                break
            }
        }

        // Normalize and store signals
        let totalEngagement = areaEngagement.values.reduce(0, +)
        let totalCompletions = areaCompletions.values.reduce(0, +)

        if totalEngagement > 0 {
            signals.lifeAreaEngagement = areaEngagement.mapValues { $0 / totalEngagement }
        }

        if totalCompletions > 0 {
            signals.completionRates = areaCompletions.mapValues { $0 / totalCompletions }
        }

        signals.skipRates = areaSkips

        let totalSuggestions = suggestionAcceptances + suggestionRejections
        if totalSuggestions > 0 {
            signals.suggestionAcceptanceRate = suggestionAcceptances / totalSuggestions
        }

        return signals
    }

    /// Calculate time decay weight (exponential decay)
    private func calculateTimeDecayWeight(eventDate: Date, now: Date) -> Double {
        let daysSince = now.timeIntervalSince(eventDate) / (24 * 60 * 60)
        // Exponential decay: weight = 0.5^(days / halfLife)
        return pow(0.5, daysSince / decayHalfLifeDays)
    }

    /// Calculate confidence score for adjustments
    private func calculateConfidence(from signals: BehaviorSignals) -> Double {
        var confidence = 0.0

        // Factor 1: Number of events (more data = more confidence)
        let eventScore = min(1.0, Double(behaviorBuffer.count) / 100.0)
        confidence += eventScore * 0.3

        // Factor 2: Recency (more recent events = more confidence)
        let recentEvents = behaviorBuffer.filter {
            Date().timeIntervalSince($0.timestamp) < 7 * 24 * 60 * 60 // Last 7 days
        }
        let recencyScore = min(1.0, Double(recentEvents.count) / 20.0)
        confidence += recencyScore * 0.3

        // Factor 3: Consistency (similar patterns = more confidence)
        let consistencyScore = calculateConsistencyScore(signals: signals)
        confidence += consistencyScore * 0.4

        return confidence
    }

    /// Check consistency of signals (are patterns stable?)
    private func calculateConsistencyScore(signals: BehaviorSignals) -> Double {
        // Compare engagement distribution to completion distribution
        guard !signals.lifeAreaEngagement.isEmpty, !signals.completionRates.isEmpty else {
            return 0.0
        }

        // Calculate correlation between engagement and completion
        var matchScore = 0.0
        for area in LifeArea.allCases {
            let engagement = signals.lifeAreaEngagement[area] ?? 0
            let completion = signals.completionRates[area] ?? 0

            // Reward similar patterns
            matchScore += 1.0 - abs(engagement - completion)
        }

        return matchScore / Double(LifeArea.allCases.count)
    }

    // MARK: - Adjustment Calculation

    /// Calculate orientation adjustments based on behavioral signals
    private func calculateAdjustments(from signals: BehaviorSignals, currentOrientation: LifeOrientationProfile) -> [String: Double] {
        var adjustments: [String: Double] = [
            "renewal": 0.0,
            "expression": 0.0,
            "care": 0.0,
            "time": 0.0
        ]

        // Analyze which life areas user is gravitating toward
        let topEngagedAreas = signals.lifeAreaEngagement.sorted { $0.value > $1.value }.prefix(3)
        let topCompletedAreas = signals.completionRates.sorted { $0.value > $1.value }.prefix(3)

        // Combined signal: areas that are both engaged AND completed highly
        var combinedSignals: [LifeArea: Double] = [:]
        for area in LifeArea.allCases {
            let engagement = signals.lifeAreaEngagement[area] ?? 0
            let completion = signals.completionRates[area] ?? 0
            let skip = signals.skipRates[area] ?? 0

            // Combined score: engagement + completion - skips
            combinedSignals[area] = (engagement * 0.4) + (completion * 0.4) - (skip * 0.2)
        }

        // Calculate dimension adjustments based on life area orientation weights
        for (area, signal) in combinedSignals {
            let weights = area.orientationWeights

            // How much is this area pulling the user in each dimension?
            // Positive signal = pull toward the direction this area represents
            let pull = (signal - 0.14) // 0.14 is neutral (1/7 areas)

            adjustments["renewal"]! += weights.renewal * pull * 0.3
            adjustments["expression"]! += weights.expression * pull * 0.3
            adjustments["care"]! += weights.care * pull * 0.3
            adjustments["time"]! += weights.time * pull * 0.3
        }

        // Clamp adjustments to max per cycle
        for key in adjustments.keys {
            adjustments[key] = max(-maxAdjustmentPerCycle, min(maxAdjustmentPerCycle, adjustments[key]!))
        }

        return adjustments
    }

    /// Clamp value to valid orientation range [0.0, 1.0]
    private func clamp(_ value: Double) -> Double {
        return max(0.0, min(1.0, value))
    }

    // MARK: - Pattern Detection

    /// Detect weekly patterns in user behavior
    func detectWeeklyPatterns() -> WeeklyPattern {
        var dayOfWeekEngagement: [Int: [LifeArea: Double]] = [:]

        let calendar = Calendar.current

        for event in behaviorBuffer {
            let dayOfWeek = calendar.component(.weekday, from: event.timestamp)

            if dayOfWeekEngagement[dayOfWeek] == nil {
                dayOfWeekEngagement[dayOfWeek] = [:]
            }

            if let area = event.lifeArea {
                let weight = calculateTimeDecayWeight(eventDate: event.timestamp, now: Date())
                dayOfWeekEngagement[dayOfWeek]![area, default: 0] += weight
            }
        }

        // Find dominant area for each day
        var pattern = WeeklyPattern()
        for day in 1...7 {
            if let engagement = dayOfWeekEngagement[day] {
                pattern.dominantAreas[day] = engagement.max(by: { $0.value < $1.value })?.key
            }
        }

        return pattern
    }

    /// Detect time-of-day patterns
    func detectTimeOfDayPatterns() -> TimeOfDayPattern {
        var hourlyEngagement: [Int: [LifeArea: Double]] = [:]

        let calendar = Calendar.current

        for event in behaviorBuffer {
            let hour = calendar.component(.hour, from: event.timestamp)

            if hourlyEngagement[hour] == nil {
                hourlyEngagement[hour] = [:]
            }

            if let area = event.lifeArea {
                let weight = calculateTimeDecayWeight(eventDate: event.timestamp, now: Date())
                hourlyEngagement[hour]![area, default: 0] += weight
            }
        }

        var pattern = TimeOfDayPattern()

        // Morning (6-12)
        var morningEngagement: [LifeArea: Double] = [:]
        for hour in 6..<12 {
            for (area, value) in hourlyEngagement[hour] ?? [:] {
                morningEngagement[area, default: 0] += value
            }
        }
        pattern.morningFocus = morningEngagement.max(by: { $0.value < $1.value })?.key

        // Afternoon (12-18)
        var afternoonEngagement: [LifeArea: Double] = [:]
        for hour in 12..<18 {
            for (area, value) in hourlyEngagement[hour] ?? [:] {
                afternoonEngagement[area, default: 0] += value
            }
        }
        pattern.afternoonFocus = afternoonEngagement.max(by: { $0.value < $1.value })?.key

        // Evening (18-24)
        var eveningEngagement: [LifeArea: Double] = [:]
        for hour in 18..<24 {
            for (area, value) in hourlyEngagement[hour] ?? [:] {
                eveningEngagement[area, default: 0] += value
            }
        }
        pattern.eveningFocus = eveningEngagement.max(by: { $0.value < $1.value })?.key

        return pattern
    }

    // MARK: - Persistence

    private var bufferFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("adaptive_behavior_buffer.json")
    }

    private func saveBehaviorBuffer() {
        do {
            let data = try JSONEncoder().encode(behaviorBuffer)
            try data.write(to: bufferFileURL)
        } catch {
            print("Failed to save behavior buffer: \(error)")
        }
    }

    private func loadBehaviorBuffer() {
        do {
            let data = try Data(contentsOf: bufferFileURL)
            behaviorBuffer = try JSONDecoder().decode([BehaviorEvent].self, from: data)
        } catch {
            behaviorBuffer = []
        }

        // Load last adaptation date
        lastAdaptationDate = UserDefaults.standard.object(forKey: "lastAdaptationDate") as? Date
    }

    private func pruneOldEvents() {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        behaviorBuffer = behaviorBuffer.filter { $0.timestamp > thirtyDaysAgo }
        saveBehaviorBuffer()

        // Save adaptation date
        UserDefaults.standard.set(lastAdaptationDate, forKey: "lastAdaptationDate")
    }

    // MARK: - Exploration vs Exploitation

    /// Occasionally suggest areas the user hasn't explored much (Spotify's "Discover Weekly" approach)
    func getExplorationSuggestion() -> LifeArea? {
        guard let profile = PersonalizationService.shared.currentProfile else { return nil }

        let currentPriorities = profile.lifeAreaScores
        let engagement = analyzeImplicitSignals().lifeAreaEngagement

        // Find areas with low engagement relative to their priority
        var explorationScores: [LifeArea: Double] = [:]

        for area in LifeArea.allCases {
            let priority = currentPriorities[area] ?? 0.5
            let engaged = engagement[area] ?? 0.0

            // High priority but low engagement = exploration opportunity
            let explorationScore = priority - engaged
            if explorationScore > 0.2 {
                explorationScores[area] = explorationScore
            }
        }

        // Return highest exploration opportunity
        return explorationScores.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Debug / Insights

    /// Get a human-readable summary of recent behavior patterns
    func getBehaviorInsights() -> [String] {
        var insights: [String] = []

        let signals = analyzeImplicitSignals()

        // Top engaged areas
        let topEngaged = signals.lifeAreaEngagement.sorted { $0.value > $1.value }.prefix(2)
        if let first = topEngaged.first {
            insights.append("You've been most engaged with \(first.key.rawValue) recently")
        }

        // Suggestion acceptance
        if signals.suggestionAcceptanceRate > 0.7 {
            insights.append("You're accepting most suggestions - the algorithm is learning well!")
        } else if signals.suggestionAcceptanceRate < 0.3 {
            insights.append("Many suggestions aren't matching your needs - we're adjusting")
        }

        // Weekly patterns
        let weeklyPattern = detectWeeklyPatterns()
        if let weekendFocus = weeklyPattern.dominantAreas[1], // Sunday
           let weekdayFocus = weeklyPattern.dominantAreas[3], // Tuesday
           weekendFocus != weekdayFocus {
            insights.append("You shift from \(weekdayFocus.rawValue) on weekdays to \(weekendFocus.rawValue) on weekends")
        }

        // Time of day patterns
        let timePattern = detectTimeOfDayPatterns()
        if let morning = timePattern.morningFocus,
           let evening = timePattern.eveningFocus,
           morning != evening {
            insights.append("Morning focus: \(morning.rawValue), Evening focus: \(evening.rawValue)")
        }

        // Exploration suggestion
        if let exploration = getExplorationSuggestion() {
            insights.append("Consider giving more attention to \(exploration.rawValue)")
        }

        return insights
    }

    /// Get the current event count (for debugging)
    var eventCount: Int {
        return behaviorBuffer.count
    }
}

// MARK: - Supporting Types

struct BehaviorEvent: Codable, Identifiable {
    let id: UUID
    let type: BehaviorEventType
    let timestamp: Date
    let lifeArea: LifeArea?
    let sphereId: UUID?
    let metadataJSON: Data

    var metadata: [String: Any] {
        get {
            (try? JSONSerialization.jsonObject(with: metadataJSON, options: []) as? [String: Any]) ?? [:]
        }
    }

    init(type: BehaviorEventType, lifeArea: LifeArea? = nil, sphereId: UUID? = nil, metadata: [String: Any] = [:]) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.lifeArea = lifeArea
        self.sphereId = sphereId
        self.metadataJSON = (try? JSONSerialization.data(withJSONObject: metadata, options: [])) ?? Data()
    }
}

enum BehaviorEventType: String, Codable {
    case taskCompleted
    case taskSkipped
    case sphereViewed
    case sphereCreated
    case suggestionAccepted
    case suggestionRejected
    case energyTimeSelected
    case loopPrioritized
}

enum SkipReason: String, Codable {
    case notNow = "not_now"
    case tooHard = "too_hard"
    case notRelevant = "not_relevant"
    case noTime = "no_time"
    case other = "other"
}

enum SuggestionType: String, Codable {
    case scheduling = "scheduling"
    case taskPriority = "task_priority"
    case sphereCreation = "sphere_creation"
    case energyBlock = "energy_block"
    case insight = "insight"
}

struct BehaviorSignals {
    var lifeAreaEngagement: [LifeArea: Double] = [:]
    var completionRates: [LifeArea: Double] = [:]
    var skipRates: [LifeArea: Double] = [:]
    var suggestionAcceptanceRate: Double = 0.5
}

struct WeeklyPattern {
    /// Day of week (1=Sunday, 7=Saturday) -> Dominant life area
    var dominantAreas: [Int: LifeArea] = [:]
}

struct TimeOfDayPattern {
    var morningFocus: LifeArea?
    var afternoonFocus: LifeArea?
    var eveningFocus: LifeArea?
}

// MARK: - Profile Adaptation History

/// Tracks how the profile has evolved over time (for transparency)
struct AdaptationHistoryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let adjustments: [String: Double]
    let confidence: Double
    let reason: String

    init(adjustments: [String: Double], confidence: Double, reason: String) {
        self.id = UUID()
        self.date = Date()
        self.adjustments = adjustments
        self.confidence = confidence
        self.reason = reason
    }
}

// MARK: - Thompson Sampling for Exploration

/// Thompson Sampling implementation for smart exploration-exploitation balance
/// Inspired by Spotify and Netflix's recommendation systems
///
/// **How it works:**
/// - Each life area has a Beta distribution (α successes, β failures)
/// - Sample from each distribution to get expected "reward"
/// - Sometimes explore less-engaged areas if they have high uncertainty
/// - Naturally balances exploitation (high α/β ratio) with exploration (low α+β)
class ThompsonSamplingExplorer {
    /// Beta distribution parameters for each life area
    /// α = success count (engagement), β = failure count (skips/ignores)
    private var alphas: [LifeArea: Double] = [:]
    private var betas: [LifeArea: Double] = [:]

    /// Initialize with uniform prior (equal chance for all areas)
    init() {
        for area in LifeArea.allCases {
            alphas[area] = 1.0  // Prior: 1 success
            betas[area] = 1.0   // Prior: 1 failure
        }
    }

    /// Update based on user engagement
    func recordEngagement(area: LifeArea, engaged: Bool) {
        if engaged {
            alphas[area, default: 1.0] += 1.0
        } else {
            betas[area, default: 1.0] += 1.0
        }
    }

    /// Sample from each area's distribution and return ranked areas
    /// Higher samples = should get more attention (either high engagement OR high uncertainty)
    func sampleRankedAreas() -> [LifeArea] {
        var samples: [(area: LifeArea, sample: Double)] = []

        for area in LifeArea.allCases {
            let alpha = alphas[area] ?? 1.0
            let beta = betas[area] ?? 1.0

            // Sample from Beta(alpha, beta) distribution
            let sample = sampleBeta(alpha: alpha, beta: beta)
            samples.append((area, sample))
        }

        // Sort by sample (highest first)
        return samples.sorted { $0.sample > $1.sample }.map { $0.area }
    }

    /// Get exploration score (high uncertainty = worth exploring)
    func explorationScore(for area: LifeArea) -> Double {
        let alpha = alphas[area] ?? 1.0
        let beta = betas[area] ?? 1.0

        // Uncertainty is high when alpha + beta is low
        // Using coefficient of variation of Beta distribution
        let variance = (alpha * beta) / ((alpha + beta) * (alpha + beta) * (alpha + beta + 1))
        let mean = alpha / (alpha + beta)

        // Higher uncertainty = higher exploration value
        return sqrt(variance) / max(mean, 0.01)
    }

    /// Get expected engagement rate (exploitation value)
    func expectedEngagementRate(for area: LifeArea) -> Double {
        let alpha = alphas[area] ?? 1.0
        let beta = betas[area] ?? 1.0
        return alpha / (alpha + beta)
    }

    /// Sample from Beta distribution using the Gamma distribution method
    private func sampleBeta(alpha: Double, beta: Double) -> Double {
        // Beta(α, β) = Gamma(α, 1) / (Gamma(α, 1) + Gamma(β, 1))
        let gammaAlpha = sampleGamma(shape: alpha)
        let gammaBeta = sampleGamma(shape: beta)
        return gammaAlpha / (gammaAlpha + gammaBeta)
    }

    /// Sample from Gamma distribution using Marsaglia and Tsang's method
    private func sampleGamma(shape: Double) -> Double {
        if shape < 1 {
            // For shape < 1, use: Gamma(shape) = Gamma(shape+1) * U^(1/shape)
            let u = Double.random(in: 0..<1)
            return sampleGamma(shape: shape + 1) * pow(u, 1.0 / shape)
        }

        let d = shape - 1.0 / 3.0
        let c = 1.0 / sqrt(9.0 * d)

        while true {
            var x: Double
            var v: Double
            repeat {
                x = gaussianRandom()
                v = 1.0 + c * x
            } while v <= 0

            v = v * v * v
            let u = Double.random(in: 0..<1)

            if u < 1.0 - 0.0331 * (x * x) * (x * x) {
                return d * v
            }

            if log(u) < 0.5 * x * x + d * (1.0 - v + log(v)) {
                return d * v
            }
        }
    }

    /// Box-Muller transform for Gaussian random numbers
    private func gaussianRandom() -> Double {
        let u1 = Double.random(in: 0..<1)
        let u2 = Double.random(in: 0..<1)
        return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    }

    /// Persist state
    func encode() -> Data? {
        let state = ThompsonState(alphas: alphas.mapKeys { $0.rawValue },
                                   betas: betas.mapKeys { $0.rawValue })
        return try? JSONEncoder().encode(state)
    }

    /// Restore state
    func decode(from data: Data) {
        guard let state = try? JSONDecoder().decode(ThompsonState.self, from: data) else { return }
        alphas = state.alphas.compactMapKeys { LifeArea(rawValue: $0) }
        betas = state.betas.compactMapKeys { LifeArea(rawValue: $0) }
    }
}

private struct ThompsonState: Codable {
    var alphas: [String: Double]
    var betas: [String: Double]
}

// MARK: - Dictionary Extensions for Key Mapping

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }

    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
}

// MARK: - Contextual Bandits for Time-Aware Recommendations

/// Contextual bandit that considers time of day and day of week
/// Learns that users prefer different life areas at different times
struct ContextualRecommender {
    /// Context: (hour bucket, day type) -> life area preferences
    /// Hour buckets: 0=night (12am-6am), 1=morning (6am-12pm), 2=afternoon (12pm-6pm), 3=evening (6pm-12am)
    /// Day type: 0=weekday, 1=weekend
    private var contextualEngagement: [String: [LifeArea: Double]] = [:]

    mutating func recordEngagement(area: LifeArea, engaged: Bool, at date: Date = Date()) {
        let context = getContext(for: date)
        let key = "\(context.hourBucket)-\(context.isWeekend ? 1 : 0)"

        if contextualEngagement[key] == nil {
            contextualEngagement[key] = [:]
        }

        let delta = engaged ? 1.0 : -0.5
        contextualEngagement[key]![area, default: 0] += delta
    }

    func getRecommendedAreas(for date: Date = Date()) -> [LifeArea] {
        let context = getContext(for: date)
        let key = "\(context.hourBucket)-\(context.isWeekend ? 1 : 0)"

        guard let engagement = contextualEngagement[key] else {
            return LifeArea.allCases  // No data for this context
        }

        return engagement.sorted { $0.value > $1.value }.map { $0.key }
    }

    private func getContext(for date: Date) -> (hourBucket: Int, isWeekend: Bool) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)

        let hourBucket: Int
        switch hour {
        case 0..<6: hourBucket = 0   // Night
        case 6..<12: hourBucket = 1  // Morning
        case 12..<18: hourBucket = 2 // Afternoon
        default: hourBucket = 3      // Evening
        }

        let isWeekend = weekday == 1 || weekday == 7 // Sunday or Saturday

        return (hourBucket, isWeekend)
    }
}

// MARK: - Profile Evolution Insights (Spotify Wrapped style)

struct ProfileEvolutionInsights {
    let weekStartDate: Date
    let weekEndDate: Date

    /// Top engaged areas this week
    var topAreasThisWeek: [LifeArea] = []

    /// How orientation has shifted
    var orientationShifts: [(dimension: String, direction: String, amount: Double)] = []

    /// Notable patterns discovered
    var patterns: [String] = []

    /// Exploration opportunities
    var underexploredAreas: [LifeArea] = []

    /// Confidence in the profile
    var profileConfidence: Double = 0.0

    /// Personalized message
    var summaryMessage: String {
        guard let topArea = topAreasThisWeek.first else {
            return "Keep using Spheres and I'll learn your patterns!"
        }

        var message = "This week, you've focused most on \(topArea.rawValue). "

        if !underexploredAreas.isEmpty {
            message += "Consider giving some attention to \(underexploredAreas[0].rawValue). "
        }

        if profileConfidence > 0.8 {
            message += "Your profile is well-calibrated to your habits."
        } else if profileConfidence > 0.5 {
            message += "I'm learning more about you each day."
        } else {
            message += "A few more weeks and I'll know you well!"
        }

        return message
    }
}

// MARK: - AdaptiveProfileService Extension for Thompson Sampling

extension AdaptiveProfileService {
    /// Get smart exploration suggestion using Thompson Sampling
    func getSmartExplorationSuggestion() -> (area: LifeArea, reason: String)? {
        let explorer = ThompsonSamplingExplorer()

        // Load state
        if let data = UserDefaults.standard.data(forKey: "thompsonSamplingState") {
            explorer.decode(from: data)
        }

        // Update with recent behavior
        for event in behaviorBuffer.suffix(100) {
            if let area = event.lifeArea {
                let engaged = event.type == .taskCompleted ||
                              event.type == .suggestionAccepted ||
                              event.type == .sphereCreated
                explorer.recordEngagement(area: area, engaged: engaged)
            }
        }

        // Save state
        if let data = explorer.encode() {
            UserDefaults.standard.set(data, forKey: "thompsonSamplingState")
        }

        // Get sampled ranking
        let rankedAreas = explorer.sampleRankedAreas()

        // Find an area that's worth exploring (high uncertainty OR underutilized)
        for area in rankedAreas {
            let explorationScore = explorer.explorationScore(for: area)
            let expectedRate = explorer.expectedEngagementRate(for: area)

            // Suggest if: high uncertainty OR low engagement but part of profile
            if explorationScore > 0.3 || expectedRate < 0.3 {
                let reason: String
                if explorationScore > 0.3 {
                    reason = "You haven't explored \(area.rawValue) much yet - it might surprise you!"
                } else {
                    reason = "\(area.rawValue) hasn't gotten much attention lately - worth a revisit?"
                }
                return (area, reason)
            }
        }

        return nil
    }

    /// Generate weekly profile evolution insights
    func generateWeeklyInsights() -> ProfileEvolutionInsights {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!

        var insights = ProfileEvolutionInsights(weekStartDate: weekStart, weekEndDate: now)

        // Get this week's events
        let weekEvents = behaviorBuffer.filter { $0.timestamp >= weekStart }

        // Calculate top areas
        var areaEngagement: [LifeArea: Int] = [:]
        for event in weekEvents {
            if let area = event.lifeArea,
               event.type == .taskCompleted || event.type == .sphereViewed {
                areaEngagement[area, default: 0] += 1
            }
        }
        insights.topAreasThisWeek = areaEngagement.sorted { $0.value > $1.value }.map { $0.key }

        // Calculate orientation shifts (compare to 2 weeks ago)
        // This would require storing historical orientation snapshots
        // For now, show pending adjustments
        for (dim, amount) in pendingAdjustments {
            if abs(amount) > 0.01 {
                let direction = amount > 0 ? "increasing" : "decreasing"
                insights.orientationShifts.append((dimension: dim, direction: direction, amount: abs(amount)))
            }
        }

        // Detect patterns
        let weeklyPattern = detectWeeklyPatterns()
        let timePattern = detectTimeOfDayPatterns()

        if let morning = timePattern.morningFocus, let evening = timePattern.eveningFocus, morning != evening {
            insights.patterns.append("Mornings: \(morning.rawValue), Evenings: \(evening.rawValue)")
        }

        // Find underexplored areas
        let allAreas = Set(LifeArea.allCases)
        let engagedAreas = Set(areaEngagement.keys)
        insights.underexploredAreas = Array(allAreas.subtracting(engagedAreas))

        // Confidence
        insights.profileConfidence = adaptationConfidence

        return insights
    }
}
