//
//  ProfileSettingsView.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  View for editing user profile, values, and AI memory
//

import SwiftUI
import SwiftData

struct ProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var personalization = PersonalizationService.shared

    @State private var displayName: String = ""
    @State private var selectedTone: CommunicationTone = .supportive
    @State private var selectedVerbosity: VerbosityLevel = .concise
    @State private var showingResetConfirmation = false
    @State private var showingMemoryEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Identity Section
                identitySection

                // Values Section
                valuesSection

                // Communication Style Section
                communicationSection

                // AI Memory Section
                memorySection

                // Actions Section
                actionsSection
            }
            .padding(24)
        }
        .background(SpheresTheme.background)
        .onAppear {
            loadProfile()
        }
        .sheet(isPresented: $showingMemoryEditor) {
            MemoryEditorView()
        }
        .alert("Reset Profile?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetProfile()
            }
        } message: {
            Text("This will clear your values quiz results, AI memories, and all personalization data. You'll need to complete onboarding again.")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profile Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("Customize your Spheres experience")
                    .font(.subheadline)
                    .foregroundColor(SpheresTheme.textSecondary)
            }

            Spacer()

            Button("Done") {
                saveProfile()
                dismiss()
            }
            .buttonStyle(SmallAccentButtonStyle())
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Identity", icon: "person.fill")

            VStack(spacing: 12) {
                HStack {
                    Text("Display Name")
                        .foregroundColor(SpheresTheme.textSecondary)

                    Spacer()

                    TextField("Your name", text: $displayName)
                        .textFieldStyle(.plain)
                        .foregroundColor(SpheresTheme.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 200)
                }
                .padding(12)
                .background(SpheresTheme.surface)
                .cornerRadius(8)

                if let profile = personalization.currentProfile {
                    HStack {
                        Text("Interactions")
                            .foregroundColor(SpheresTheme.textSecondary)

                        Spacer()

                        Text("\(profile.interactionCount)")
                            .foregroundColor(SpheresTheme.textPrimary)
                    }
                    .padding(12)
                    .background(SpheresTheme.surface)
                    .cornerRadius(8)

                    HStack {
                        Text("Personalization Depth")
                            .foregroundColor(SpheresTheme.textSecondary)

                        Spacer()

                        Text(personalization.personalizationDepth.description)
                            .foregroundColor(SpheresTheme.accent)
                    }
                    .padding(12)
                    .background(SpheresTheme.surface)
                    .cornerRadius(8)
                }
            }
        }
    }

    private var valuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Your Values", icon: "heart.fill")

            if let profile = personalization.currentProfile {
                let topValues = profile.topValues(count: 5)

                if topValues.isEmpty {
                    emptyValuesState
                } else {
                    VStack(spacing: 8) {
                        ForEach(topValues, id: \.self) { value in
                            valueRow(value, score: profile.valuesScores[value] ?? 0)
                        }
                    }

                    // Value dimensions
                    VStack(spacing: 8) {
                        dimensionBar(
                            title: "Openness ↔ Conservation",
                            value: averageOpennessScore(topValues)
                        )

                        dimensionBar(
                            title: "Self-Enhancement ↔ Self-Transcendence",
                            value: averageSelfTranscendenceScore(topValues)
                        )
                    }
                    .padding(.top, 8)
                }
            } else {
                emptyValuesState
            }
        }
    }

    private var emptyValuesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 32))
                .foregroundColor(SpheresTheme.textMuted)

            Text("No values quiz completed yet")
                .foregroundColor(SpheresTheme.textSecondary)

            Button("Take Values Quiz") {
                // Trigger onboarding
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                dismiss()
            }
            .buttonStyle(SmallAccentButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(SpheresTheme.surface)
        .cornerRadius(12)
    }

    private func valueRow(_ value: SchwartzValue, score: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: value.icon)
                .font(.system(size: 16))
                .foregroundColor(value.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(value.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SpheresTheme.textPrimary)

                Text(value.description)
                    .font(.caption)
                    .foregroundColor(SpheresTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Score indicator
            Circle()
                .fill(value.color.opacity(score))
                .frame(width: 12, height: 12)

            Text("\(Int(score * 100))%")
                .font(.caption)
                .foregroundColor(SpheresTheme.textSecondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(12)
        .background(SpheresTheme.surface)
        .cornerRadius(8)
    }

    private func dimensionBar(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(SpheresTheme.textSecondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(SpheresTheme.surface)

                    // Indicator
                    Circle()
                        .fill(SpheresTheme.accent)
                        .frame(width: 12, height: 12)
                        .offset(x: (geo.size.width - 12) * value)
                }
            }
            .frame(height: 12)
        }
    }

    private var communicationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Communication Style", icon: "bubble.left.fill")

            VStack(spacing: 12) {
                // Tone picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tone")
                        .font(.subheadline)
                        .foregroundColor(SpheresTheme.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(CommunicationTone.allCases, id: \.self) { tone in
                            toneButton(tone)
                        }
                    }
                }
                .padding(12)
                .background(SpheresTheme.surface)
                .cornerRadius(8)

                // Verbosity picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response Length")
                        .font(.subheadline)
                        .foregroundColor(SpheresTheme.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(VerbosityLevel.allCases, id: \.self) { level in
                            verbosityButton(level)
                        }
                    }
                }
                .padding(12)
                .background(SpheresTheme.surface)
                .cornerRadius(8)
            }
        }
    }

    private func toneButton(_ tone: CommunicationTone) -> some View {
        Button {
            selectedTone = tone
        } label: {
            Text(tone.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(selectedTone == tone ? SpheresTheme.textPrimary : SpheresTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedTone == tone ? SpheresTheme.accent : SpheresTheme.surfaceElevated)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func verbosityButton(_ level: VerbosityLevel) -> some View {
        Button {
            selectedVerbosity = level
        } label: {
            Text(level.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(selectedVerbosity == level ? SpheresTheme.textPrimary : SpheresTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedVerbosity == level ? SpheresTheme.accent : SpheresTheme.surfaceElevated)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("AI Memory", icon: "brain")

            VStack(spacing: 12) {
                if let profile = personalization.currentProfile {
                    let memories = profile.rememberedFacts

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(memories.count) memories stored")
                                .foregroundColor(SpheresTheme.textPrimary)

                            Text("Things I remember about you")
                                .font(.caption)
                                .foregroundColor(SpheresTheme.textSecondary)
                        }

                        Spacer()

                        Button("View All") {
                            showingMemoryEditor = true
                        }
                        .buttonStyle(SmallGhostButtonStyle())
                    }
                    .padding(12)
                    .background(SpheresTheme.surface)
                    .cornerRadius(8)

                    // Show preview of top memories
                    if !memories.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(memories.prefix(3)) { memory in
                                memoryPreviewRow(memory)
                            }
                        }
                    }
                } else {
                    Text("No memories yet")
                        .foregroundColor(SpheresTheme.textSecondary)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(SpheresTheme.surface)
                        .cornerRadius(8)
                }
            }
        }
    }

    private func memoryPreviewRow(_ memory: MemoryItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(colorForPriority(memory.priority))
                .frame(width: 6, height: 6)

            Text(memory.content)
                .font(.caption)
                .foregroundColor(SpheresTheme.textSecondary)
                .lineLimit(1)

            Spacer()

            Text(memory.category.rawValue)
                .font(.caption2)
                .foregroundColor(SpheresTheme.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(SpheresTheme.surface.opacity(0.5))
        .cornerRadius(6)
    }

    private func colorForPriority(_ priority: MemoryPriority) -> Color {
        switch priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .ephemeral: return .gray
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Actions", icon: "gear")

            VStack(spacing: 8) {
                Button {
                    // Retake quiz
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Retake Values Quiz")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(SpheresTheme.textPrimary)
                    .padding(12)
                    .background(SpheresTheme.surface)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    showingResetConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Reset All Profile Data")
                        Spacer()
                    }
                    .foregroundColor(.red)
                    .padding(12)
                    .background(SpheresTheme.surface)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(SpheresTheme.accent)
            Text(title)
                .font(.headline)
                .foregroundColor(SpheresTheme.textPrimary)
        }
    }

    private func loadProfile() {
        if let profile = personalization.currentProfile {
            displayName = profile.displayName
            selectedTone = profile.tone
            selectedVerbosity = profile.verbosity
        }
    }

    private func saveProfile() {
        guard let profile = personalization.currentProfile else { return }
        profile.displayName = displayName
        profile.tone = selectedTone
        profile.verbosity = selectedVerbosity
        profile.lastUpdated = Date()

        try? modelContext.save()
    }

    private func resetProfile() {
        DataManager.shared.clearAllDataForOnboarding(modelContext: modelContext)
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "userEnergyProfile")
        dismiss()
    }

    private func averageOpennessScore(_ values: [SchwartzValue]) -> Double {
        guard !values.isEmpty else { return 0.5 }
        return values.map { $0.opennessScore }.reduce(0, +) / Double(values.count)
    }

    private func averageSelfTranscendenceScore(_ values: [SchwartzValue]) -> Double {
        guard !values.isEmpty else { return 0.5 }
        return values.map { $0.selfTranscendenceScore }.reduce(0, +) / Double(values.count)
    }
}

// MARK: - PersonalizationDepth Description

extension PersonalizationDepth {
    var description: String {
        switch self {
        case .minimal: return "Getting to know you"
        case .moderate: return "Building understanding"
        case .deep: return "Well connected"
        case .complete: return "Deeply personalized"
        }
    }
}

// MARK: - Memory Editor View

struct MemoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var personalization = PersonalizationService.shared

    @State private var memories: [MemoryItem] = []
    @State private var searchText = ""

    var filteredMemories: [MemoryItem] {
        if searchText.isEmpty {
            return memories.sorted { $0.priority.rawValue > $1.priority.rawValue }
        }
        return memories.filter {
            $0.content.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Memories")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(SpheresTheme.textPrimary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(SmallAccentButtonStyle())
            }
            .padding()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(SpheresTheme.textMuted)
                TextField("Search memories...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(SpheresTheme.textPrimary)
            }
            .padding(10)
            .background(SpheresTheme.surface)
            .cornerRadius(8)
            .padding(.horizontal)

            // Memory list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredMemories) { memory in
                        MemoryRow(memory: memory) {
                            deleteMemory(memory)
                        }
                    }
                }
                .padding()
            }

            // Footer
            HStack {
                Text("\(memories.count) memories")
                    .font(.caption)
                    .foregroundColor(SpheresTheme.textSecondary)

                Spacer()

                Button("Clear Ephemeral") {
                    clearEphemeral()
                }
                .buttonStyle(SmallGhostButtonStyle())
            }
            .padding()
        }
        .background(SpheresTheme.background)
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            loadMemories()
        }
    }

    private func loadMemories() {
        memories = personalization.currentProfile?.rememberedFacts ?? []
    }

    private func deleteMemory(_ memory: MemoryItem) {
        memories.removeAll { $0.id == memory.id }
        personalization.currentProfile?.rememberedFacts = memories
    }

    private func clearEphemeral() {
        memories.removeAll { $0.priority == .ephemeral }
        personalization.currentProfile?.rememberedFacts = memories
    }
}

struct MemoryRow: View {
    let memory: MemoryItem
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(memory.content)
                    .font(.subheadline)
                    .foregroundColor(SpheresTheme.textPrimary)

                HStack(spacing: 8) {
                    Text(memory.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(SpheresTheme.textMuted)

                    Text("•")
                        .foregroundColor(SpheresTheme.textMuted)

                    Text(memory.priority.displayName)
                        .font(.caption2)
                        .foregroundColor(SpheresTheme.textMuted)

                    Text("•")
                        .foregroundColor(SpheresTheme.textMuted)

                    Text(formatDate(memory.createdAt))
                        .font(.caption2)
                        .foregroundColor(SpheresTheme.textMuted)
                }
            }

            Spacer()

            // Delete button (on hover)
            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(SpheresTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(SpheresTheme.surface)
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var priorityColor: Color {
        switch memory.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .ephemeral: return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension MemoryPriority {
    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .ephemeral: return "Ephemeral"
        }
    }
}

// MARK: - Settings Section for ContentView

/// Settings section card for personalization (used in SettingsView)
struct PersonalizationSettingsSection: View {
    @ObservedObject private var personalization = PersonalizationService.shared
    @State private var showingProfileSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PERSONALIZATION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(SpheresTheme.textTertiary)
                .tracking(1)

            VStack(alignment: .leading, spacing: 16) {
                // Status
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(hasProfile ? Color.purple.opacity(0.15) : Color.orange.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: hasProfile ? "person.fill.checkmark" : "person.fill.questionmark")
                            .font(.system(size: 20))
                            .foregroundColor(hasProfile ? .purple : .orange)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Values Profile")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)

                        if hasProfile {
                            if let profile = personalization.currentProfile {
                                let topValues = profile.topValues(count: 2)
                                if !topValues.isEmpty {
                                    Text("Top values: \(topValues.map { $0.rawValue }.joined(separator: ", "))")
                                        .font(.system(size: 12))
                                        .foregroundColor(SpheresTheme.textSecondary)
                                }
                            }
                        } else {
                            Text("Not configured — complete quiz for personalization")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }

                    Spacer()
                }

                if hasProfile, let profile = personalization.currentProfile {
                    Divider().background(SpheresTheme.border)

                    // Quick stats
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("Interactions")
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.textTertiary)
                            Text("\(profile.interactionCount)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(SpheresTheme.textPrimary)
                        }

                        VStack(spacing: 4) {
                            Text("Memories")
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.textTertiary)
                            Text("\(profile.rememberedFacts.count)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(SpheresTheme.textPrimary)
                        }

                        VStack(spacing: 4) {
                            Text("Tone")
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.textTertiary)
                            Text(profile.tone.rawValue.capitalized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(SpheresTheme.textPrimary)
                        }

                        VStack(spacing: 4) {
                            Text("Depth")
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.textTertiary)
                            Text(personalization.personalizationDepth.shortName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.purple)
                        }
                    }
                }

                Divider().background(SpheresTheme.border)

                // Button to open full profile settings
                Button {
                    showingProfileSettings = true
                } label: {
                    HStack {
                        Text(hasProfile ? "Edit Profile Settings" : "Set Up Profile")
                            .font(.system(size: 13))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(SpheresTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
        }
        .sheet(isPresented: $showingProfileSettings) {
            ProfileSettingsView()
                .frame(minWidth: 500, minHeight: 600)
        }
    }

    private var hasProfile: Bool {
        guard let profile = personalization.currentProfile else { return false }
        return !profile.coreValues.isEmpty
    }
}

extension PersonalizationDepth {
    var shortName: String {
        switch self {
        case .minimal: return "Basic"
        case .moderate: return "Moderate"
        case .deep: return "Deep"
        case .complete: return "Complete"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ProfileSettingsView()
        .frame(width: 500, height: 700)
}

#Preview("Personalization Section") {
    PersonalizationSettingsSection()
        .padding()
        .background(SpheresTheme.background)
        .frame(width: 400)
}
#endif
