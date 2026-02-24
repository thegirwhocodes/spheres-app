//
//  AdaptiveTracking.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Easy integration hooks for tracking user behavior throughout the app
//

import Foundation
import SwiftUI

// MARK: - Global Tracking Functions

/// Track when a task/loop is completed
/// Call this when: user marks a loop as complete, closes a loop
@MainActor
func trackLoopCompleted(_ loop: OpenLoopModel, duration: TimeInterval? = nil) {
    let lifeArea = mapSphereToLifeArea(loop.sphere)
    AdaptiveProfileService.shared.trackTaskCompletion(
        sphereId: loop.sphere?.id ?? UUID(),
        lifeArea: lifeArea,
        duration: duration ?? 0,
        wasOnTime: loop.dueDate == nil || loop.dueDate! >= Date()
    )
}

/// Track when a task is skipped or deferred
/// Call this when: user swipes to dismiss, reschedules, or says "not now"
@MainActor
func trackLoopSkipped(_ loop: OpenLoopModel, reason: SkipReason = .notNow) {
    let lifeArea = mapSphereToLifeArea(loop.sphere)
    AdaptiveProfileService.shared.trackTaskSkip(
        sphereId: loop.sphere?.id ?? UUID(),
        lifeArea: lifeArea,
        reason: reason
    )
}

/// Track time spent viewing a sphere
/// Call this when: user navigates away from sphere detail view
@MainActor
func trackSphereViewed(_ sphere: SphereModel, duration: TimeInterval) {
    let lifeArea = mapSphereToLifeArea(sphere)
    AdaptiveProfileService.shared.trackSphereEngagement(
        sphereId: sphere.id,
        lifeArea: lifeArea,
        duration: duration
    )
}

/// Track when a new sphere is created
/// Call this when: user creates a new sphere
@MainActor
func trackSphereCreated(_ sphere: SphereModel) {
    let lifeArea = mapSphereToLifeArea(sphere)
    AdaptiveProfileService.shared.trackSphereCreated(
        sphereId: sphere.id,
        lifeArea: lifeArea
    )
}

/// Track when an AI scheduling suggestion is accepted
/// Call this when: user accepts a time block suggestion
@MainActor
func trackSchedulingSuggestionAccepted(forArea lifeArea: LifeArea?) {
    AdaptiveProfileService.shared.trackSuggestionAccepted(
        type: .scheduling,
        lifeArea: lifeArea
    )
}

/// Track when an AI scheduling suggestion is rejected
/// Call this when: user dismisses or ignores a time block suggestion
@MainActor
func trackSchedulingSuggestionRejected(forArea lifeArea: LifeArea?) {
    AdaptiveProfileService.shared.trackSuggestionRejected(
        type: .scheduling,
        lifeArea: lifeArea
    )
}

/// Track when user selects a time for deep work
/// Call this when: user manually schedules a task at a specific time
@MainActor
func trackEnergyTimeSelected(hour: Int, taskCategory: String) {
    AdaptiveProfileService.shared.trackEnergyTimeSelection(
        hour: hour,
        taskCategory: taskCategory
    )
}

// MARK: - Sphere to Life Area Mapping

/// Maps a sphere to its corresponding life area based on name/icon
func mapSphereToLifeArea(_ sphere: SphereModel?) -> LifeArea? {
    guard let sphere = sphere else { return nil }

    let name = sphere.name.lowercased()

    // Check for exact or partial matches
    if name.contains("faith") || name.contains("spiritual") || name.contains("prayer") || name.contains("church") {
        return .faith
    }
    if name.contains("family") || name.contains("kids") || name.contains("parenting") || name.contains("marriage") {
        return .family
    }
    if name.contains("health") || name.contains("fitness") || name.contains("exercise") || name.contains("wellness") || name.contains("gym") {
        return .health
    }
    if name.contains("work") || name.contains("career") || name.contains("job") || name.contains("business") || name.contains("project") {
        return .work
    }
    if name.contains("finance") || name.contains("money") || name.contains("budget") || name.contains("invest") || name.contains("savings") {
        return .finances
    }
    if name.contains("community") || name.contains("service") || name.contains("volunteer") || name.contains("friends") || name.contains("social") {
        return .community
    }
    if name.contains("growth") || name.contains("learn") || name.contains("education") || name.contains("creative") || name.contains("hobby") || name.contains("read") {
        return .growth
    }

    // Check icon as fallback
    switch sphere.icon {
    case "sparkles", "cross.fill", "book.closed.fill":
        return .faith
    case "figure.2.and.child.holdinghands", "heart.fill", "house.fill":
        return .family
    case "heart.circle.fill", "figure.run", "leaf.fill":
        return .health
    case "briefcase.fill", "building.2.fill", "laptopcomputer":
        return .work
    case "dollarsign.circle.fill", "banknote.fill", "chart.line.uptrend.xyaxis":
        return .finances
    case "person.3.fill", "globe.americas.fill", "hands.sparkles.fill":
        return .community
    case "arrow.up.circle.fill", "book.fill", "lightbulb.fill", "paintbrush.fill":
        return .growth
    default:
        return nil
    }
}

// MARK: - View Modifier for Time Tracking

/// Automatically track view duration when a sphere detail view appears/disappears
struct SphereViewTimeTracker: ViewModifier {
    let sphere: SphereModel
    @State private var appearTime: Date?

    func body(content: Content) -> some View {
        content
            .onAppear {
                appearTime = Date()
            }
            .onDisappear {
                if let appear = appearTime {
                    let duration = Date().timeIntervalSince(appear)
                    trackSphereViewed(sphere, duration: duration)
                }
            }
    }
}

extension View {
    /// Track how long user spends viewing this sphere
    func trackingViewTime(for sphere: SphereModel) -> some View {
        modifier(SphereViewTimeTracker(sphere: sphere))
    }
}

// MARK: - Loop Completion Tracking Modifier

/// Automatically track when loops are completed
struct LoopCompletionTracker: ViewModifier {
    let loop: OpenLoopModel
    @State private var wasComplete: Bool

    init(loop: OpenLoopModel) {
        self.loop = loop
        self._wasComplete = State(initialValue: loop.isCompleted)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: loop.isCompleted) { oldValue, newValue in
                if !oldValue && newValue {
                    // Loop was just completed
                    trackLoopCompleted(loop)
                }
            }
    }
}

extension View {
    /// Track when this loop's completion status changes
    func trackingCompletion(of loop: OpenLoopModel) -> some View {
        modifier(LoopCompletionTracker(loop: loop))
    }
}

// MARK: - Suggestion Response Tracking

/// Track user response to AI suggestions
enum SuggestionResponse {
    case accepted
    case rejected
    case deferred
}

@MainActor
func trackSuggestionResponse(_ response: SuggestionResponse, type: SuggestionType, lifeArea: LifeArea?) {
    switch response {
    case .accepted:
        AdaptiveProfileService.shared.trackSuggestionAccepted(type: type, lifeArea: lifeArea)
    case .rejected, .deferred:
        AdaptiveProfileService.shared.trackSuggestionRejected(type: type, lifeArea: lifeArea)
    }
}

// MARK: - Quick Access to Insights

/// Get the current profile confidence level
@MainActor
var profileConfidence: Double {
    AdaptiveProfileService.shared.adaptationConfidence
}

/// Get a smart exploration suggestion
@MainActor
var explorationSuggestion: (area: LifeArea, reason: String)? {
    AdaptiveProfileService.shared.getSmartExplorationSuggestion()
}

/// Get behavioral insights as strings
@MainActor
var behaviorInsights: [String] {
    AdaptiveProfileService.shared.getBehaviorInsights()
}

// MARK: - Debug Helpers

#if DEBUG
/// Force run the adaptation algorithm (for testing)
func debugForceAdaptation() {
    Task {
        await AdaptiveProfileService.shared.runAdaptation()
    }
}

/// Simulate some behavior events (for testing)
@MainActor
func debugSimulateBehavior() {
    let service = AdaptiveProfileService.shared

    // Simulate a week of behavior
    for area in [LifeArea.work, .health, .faith] {
        for _ in 0..<10 {
            service.trackEvent(BehaviorEvent(
                type: .taskCompleted,
                lifeArea: area,
                metadata: ["duration": Double.random(in: 300...3600)]
            ))
        }
    }

    // Simulate some skips
    for area in [LifeArea.finances, .community] {
        for _ in 0..<3 {
            service.trackEvent(BehaviorEvent(
                type: .taskSkipped,
                lifeArea: area,
                metadata: ["reason": SkipReason.notNow.rawValue]
            ))
        }
    }

    print("Simulated behavior events. Event count: \(service.eventCount)")
}
#endif
