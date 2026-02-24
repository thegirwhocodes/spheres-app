//
//  ProfileInsightsView.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  "Wrapped" style insights showing how the profile has evolved
//

import SwiftUI

// MARK: - Profile Insights View (Main)

struct ProfileInsightsView: View {
    @ObservedObject var adaptiveService = AdaptiveProfileService.shared
    @State private var insights: ProfileEvolutionInsights?
    @State private var behaviorInsights: [String] = []
    @State private var showingDetailedView = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Profile")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("How I'm learning about you")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                ProfileConfidenceBadge(confidence: adaptiveService.adaptationConfidence)
            }
            .padding(.horizontal)

            // Quick Stats
            HStack(spacing: 16) {
                InsightStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    value: "\(adaptiveService.eventCount)",
                    label: "Interactions"
                )
                InsightStatCard(
                    icon: "brain.head.profile",
                    value: String(format: "%.0f%%", adaptiveService.adaptationConfidence * 100),
                    label: "Confidence"
                )
                if let lastDate = adaptiveService.lastAdaptationDate {
                    InsightStatCard(
                        icon: "arrow.triangle.2.circlepath",
                        value: lastDate.timeAgoShort(),
                        label: "Last Update"
                    )
                }
            }
            .padding(.horizontal)

            // Weekly Insights Card
            if let insights = insights {
                WeeklyInsightsCard(insights: insights)
                    .padding(.horizontal)
            }

            // Behavior Insights
            if !behaviorInsights.isEmpty {
                BehaviorInsightsList(insights: behaviorInsights)
                    .padding(.horizontal)
            }

            // Exploration Suggestion
            if let (area, reason) = adaptiveService.getSmartExplorationSuggestion() {
                ExplorationSuggestionCard(area: area, reason: reason)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top)
        .background(Color(red: 0.04, green: 0.04, blue: 0.05))
        .onAppear {
            insights = adaptiveService.generateWeeklyInsights()
            behaviorInsights = adaptiveService.getBehaviorInsights()
        }
    }
}

// MARK: - Supporting Views

struct ProfileConfidenceBadge: View {
    let confidence: Double

    var confidenceColor: Color {
        switch confidence {
        case 0.8...: return .green
        case 0.5..<0.8: return .yellow
        default: return .orange
        }
    }

    var confidenceText: String {
        switch confidence {
        case 0.8...: return "Well Calibrated"
        case 0.5..<0.8: return "Learning"
        default: return "Getting Started"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            Text(confidenceText)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(confidenceColor.opacity(0.2))
        .cornerRadius(20)
    }
}

struct InsightStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(red: 0.55, green: 0.36, blue: 0.96))

            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)

            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct WeeklyInsightsCard: View {
    let insights: ProfileEvolutionInsights

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(Color(red: 0.55, green: 0.36, blue: 0.96))
                Text("This Week")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            // Summary message
            Text(insights.summaryMessage)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            // Top areas visualization
            if !insights.topAreasThisWeek.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(insights.topAreasThisWeek.prefix(4)), id: \.self) { area in
                        LifeAreaPill(area: area)
                    }
                }
            }

            // Orientation shifts
            if !insights.orientationShifts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Profile Adjustments")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))

                    ForEach(insights.orientationShifts, id: \.dimension) { shift in
                        HStack {
                            Text(shift.dimension.capitalized)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: shift.direction == "increasing" ? "arrow.up.right" : "arrow.down.right")
                                    .font(.caption2)
                                Text(String(format: "%.1f%%", shift.amount * 100))
                                    .font(.caption.monospacedDigit())
                            }
                            .foregroundColor(shift.direction == "increasing" ? .green : .orange)
                        }
                    }
                }
            }

            // Patterns discovered
            if !insights.patterns.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Patterns Discovered")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))

                    ForEach(insights.patterns, id: \.self) { pattern in
                        HStack {
                            Image(systemName: "clock.arrow.2.circlepath")
                                .font(.caption)
                                .foregroundColor(Color(red: 0.55, green: 0.36, blue: 0.96))
                            Text(pattern)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct LifeAreaPill: View {
    let area: LifeArea

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: area.icon)
                .font(.caption2)
            Text(area.rawValue)
                .font(.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(area.color.opacity(0.2))
        .foregroundColor(area.color)
        .cornerRadius(20)
    }
}

struct BehaviorInsightsList: View {
    let insights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Insights")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            ForEach(insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color(red: 0.55, green: 0.36, blue: 0.96))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    Text(insight)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct ExplorationSuggestionCard: View {
    let area: LifeArea
    let reason: String
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(red: 0.55, green: 0.36, blue: 0.96))
                    Text("Discovery Suggestion")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        withAnimation {
                            isDismissed = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(area.color.opacity(0.2))
                            .frame(width: 50, height: 50)
                        Image(systemName: area.icon)
                            .font(.title2)
                            .foregroundColor(area.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(area.rawValue)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [area.color.opacity(0.1), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(area.color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Compact Insights Widget (for Home view)

struct CompactProfileInsightsWidget: View {
    @ObservedObject var adaptiveService = AdaptiveProfileService.shared
    @State private var exploration: (area: LifeArea, reason: String)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(Color(red: 0.55, green: 0.36, blue: 0.96))
                Text("Profile Evolution")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.0f%% confident", adaptiveService.adaptationConfidence * 100))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            if let exploration = exploration {
                HStack {
                    Image(systemName: exploration.area.icon)
                        .foregroundColor(exploration.area.color)
                    Text("Try focusing on \(exploration.area.rawValue)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                Text("Tracking your patterns to personalize suggestions...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            exploration = adaptiveService.getSmartExplorationSuggestion()
        }
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgoShort() -> String {
        let seconds = Date().timeIntervalSince(self)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if days >= 1 {
            return "\(Int(days))d ago"
        } else if hours >= 1 {
            return "\(Int(hours))h ago"
        } else if minutes >= 1 {
            return "\(Int(minutes))m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileInsightsView()
}
