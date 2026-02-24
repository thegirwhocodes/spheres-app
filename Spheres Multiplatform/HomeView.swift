//
//  HomeView.swift
//  Spheres - Smart Life Manager
//
//  Home dashboard with resurfacing, stats, and streaks.
//

import SwiftUI
import SwiftData

// MARK: - Home View
struct HomeView: View {
    @Query(sort: \OpenLoopModel.createdDate) private var allLoops: [OpenLoopModel]
    @Query(sort: \SphereModel.priorityRank) private var spheres: [SphereModel]
    @StateObject private var aiService = AIService.shared
    @State private var aiSuggestions: [ResurfacingSuggestion] = []
    @State private var isLoadingAI = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 17 { return "Good afternoon" }
        else { return "Good evening" }
    }

    private var completedThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allLoops.filter { $0.isCompleted && ($0.completedDate ?? $0.createdDate) > weekAgo }.count
    }

    private var openLoops: Int {
        allLoops.filter { !$0.isCompleted }.count
    }

    private var highPriority: Int {
        allLoops.filter { !$0.isCompleted && $0.importance <= 2 }.count
    }

    private var localResurfacingItems: [OpenLoopModel] {
        allLoops
            .filter { !$0.isCompleted && $0.importance <= 2 }
            .sorted { $0.createdDate < $1.createdDate }
            .prefix(5)
            .map { $0 }
    }

    private var totalTimeThisWeek: Int {
        allLoops.reduce(0) { $0 + $1.timeSpentSeconds }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(greeting)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(SpheresTheme.textPrimary)

                    Text("Here's what's on your mind today")
                        .font(.system(size: 15))
                        .foregroundColor(SpheresTheme.textSecondary)
                }
                .padding(.top, 8)

                // iCloud Sync Banner
                SyncSetupBanner()

                // Resurfacing Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("RESURFACING TODAY")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .tracking(1)

                        if aiService.hasAPIKey && !aiSuggestions.isEmpty {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.accent)
                        }

                        Spacer()

                        if isLoadingAI {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }

                    if !aiSuggestions.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(aiSuggestions) { suggestion in
                                ResurfaceItemWithReason(loop: suggestion.loop, reason: suggestion.reason)
                            }
                        }
                    } else if localResurfacingItems.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                            Text("No high-priority items right now!")
                                .font(.system(size: 14))
                                .foregroundColor(SpheresTheme.textSecondary)
                        }
                        .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(localResurfacingItems) { loop in
                                ResurfaceItemReal(loop: loop)
                            }
                        }
                    }
                }

                // Quick Stats
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR WEEK")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .tracking(1)

                    HStack(spacing: 16) {
                        StatCard(value: "\(completedThisWeek)", label: "Completed", icon: "checkmark.circle.fill", color: .green)
                        StatCard(value: "\(openLoops)", label: "Open Loops", icon: "circle.dotted", color: .orange)
                        StatCard(value: "\(highPriority)", label: "High Priority", icon: "exclamationmark.circle.fill", color: .red)
                    }

                    if totalTimeThisWeek > 0 {
                        HStack(spacing: 16) {
                            StatCard(value: formatTotalTime(totalTimeThisWeek), label: "Time Tracked", icon: "clock.fill", color: .blue)
                        }
                    }
                }

                // Active habits with streaks
                let activeHabits = allLoops.filter { $0.isHabit && $0.currentStreak > 0 }
                if !activeHabits.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ACTIVE STREAKS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .tracking(1)

                        VStack(spacing: 8) {
                            ForEach(activeHabits.sorted { $0.currentStreak > $1.currentStreak }.prefix(3)) { habit in
                                HStack(spacing: 12) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)

                                    Text(habit.content)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(SpheresTheme.textPrimary)
                                        .lineLimit(1)

                                    Spacer()

                                    Text("\(habit.currentStreak) days")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.orange)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(SpheresTheme.surface)
                                )
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(32)
        }
        .onAppear {
            fetchAISuggestions()
        }
    }

    private func fetchAISuggestions() {
        let openLoops = allLoops.filter { !$0.isCompleted }
        guard !openLoops.isEmpty else { return }

        isLoadingAI = true
        Task {
            let suggestions = await aiService.getResurfacingSuggestions(loops: openLoops, spheres: spheres)
            await MainActor.run {
                aiSuggestions = suggestions
                isLoadingAI = false
            }
        }
    }

    func formatTotalTime(_ seconds: Int) -> String {
        if seconds < 3600 {
            return "\(seconds / 60)m"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Resurfacing Items

struct ResurfaceItemWithReason: View {
    let loop: OpenLoopModel
    let reason: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i < loop.importance ? (loop.sphere?.color ?? SpheresTheme.accent) : SpheresTheme.border)
                        .frame(width: 5, height: 5)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(loop.content)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let sphere = loop.sphere {
                        Circle()
                            .fill(sphere.color)
                            .frame(width: 6, height: 6)
                        Text(sphere.name)
                            .font(.system(size: 11))
                    }
                    Text("•")
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundColor(SpheresTheme.accent)
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.accent)
                }
                .foregroundColor(SpheresTheme.textTertiary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
        )
        .onHover { isHovered = $0 }
    }
}

struct ResurfaceItemReal: View {
    let loop: OpenLoopModel
    @State private var isHovered = false

    private var daysOld: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: loop.createdDate, to: Date()).day ?? 0
    }

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i < loop.importance ? (loop.sphere?.color ?? SpheresTheme.accent) : SpheresTheme.border)
                        .frame(width: 5, height: 5)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(loop.content)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let sphere = loop.sphere {
                        Circle()
                            .fill(sphere.color)
                            .frame(width: 6, height: 6)
                        Text(sphere.name)
                            .font(.system(size: 11))
                    }
                    Text("•")
                    Text("\(daysOld)d ago")
                        .font(.system(size: 11))
                }
                .foregroundColor(SpheresTheme.textTertiary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
        )
        .onHover { isHovered = $0 }
    }
}

struct ResurfaceItem: View {
    let content: String
    let sphere: String
    let sphereColor: Color
    let importance: Int
    let daysOld: Int
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i < importance ? sphereColor : SpheresTheme.border)
                        .frame(width: 5, height: 5)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(content)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(sphereColor)
                        .frame(width: 6, height: 6)
                    Text(sphere)
                        .font(.system(size: 11))
                    Text("•")
                    Text("\(daysOld)d ago")
                        .font(.system(size: 11))
                }
                .foregroundColor(SpheresTheme.textTertiary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 6) {
                    Button(action: {}) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(TinyIconButtonStyle())

                    Button(action: {}) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(TinyIconButtonStyle())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(SpheresTheme.textPrimary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(SpheresTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SpheresTheme.surface)
        )
    }
}

#Preview("Home View") {
    HomeView()
        .modelContainer(previewContainer)
        .frame(width: 700, height: 500)
}
