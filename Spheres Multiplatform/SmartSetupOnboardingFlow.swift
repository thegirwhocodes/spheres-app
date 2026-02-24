//
//  SmartSetupOnboardingFlow.swift
//  Spheres - Smart Life Manager
//
//  4-step AI-powered onboarding: Welcome → Permissions → AI Scan → Review
//  Replaces the 10-step UnifiedOnboardingFlow
//

import SwiftUI
import SwiftData

// MARK: - Smart Setup Steps

enum SmartSetupStep: Int, CaseIterable {
    case welcome = 0
    case permissions = 1
    case scanning = 2
    case review = 3

    var progress: CGFloat {
        CGFloat(rawValue) / CGFloat(Self.allCases.count - 1)
    }
}

// MARK: - Smart Setup Onboarding Flow

struct SmartSetupOnboardingFlow: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @StateObject private var setupService = SmartSetupService.shared
    @State private var currentStep: SmartSetupStep = .welcome
    @State private var userName: String = ""
    @AppStorage("claudeAPIKey") private var apiKey: String = ""

    var body: some View {
        ZStack {
            SpheresTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(SpheresTheme.border)
                            .frame(height: 3)
                        Rectangle()
                            .fill(SpheresTheme.accent)
                            .frame(width: geo.size.width * currentStep.progress, height: 3)
                    }
                }
                .frame(height: 3)

                // Step content
                Group {
                    switch currentStep {
                    case .welcome:
                        welcomeStep
                    case .permissions:
                        permissionsStep
                    case .scanning:
                        scanningStep
                    case .review:
                        reviewStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            ZStack {
                Circle()
                    .fill(SpheresTheme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 44))
                    .foregroundColor(SpheresTheme.accent)
            }

            VStack(spacing: 12) {
                Text("Welcome to Spheres")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("Your AI-powered life manager.\nWe'll scan your Mac to set things up automatically.")
                    .font(.system(size: 16))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("What should we call you?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                TextField("Your name", text: $userName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(SpheresTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(SpheresTheme.border, lineWidth: 1)
                            )
                    )
            }
            .frame(maxWidth: 300)

            // API key (if not set)
            if apiKey.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude API Key")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)

                    SecureField("sk-ant-...", text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(SpheresTheme.textPrimary)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SpheresTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(SpheresTheme.border, lineWidth: 1)
                                )
                        )

                    Text("Needed for AI-powered setup. Get one at console.anthropic.com")
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
                .frame(maxWidth: 300)
            }

            Spacer()

            // Next button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = .permissions
                }
            }) {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SpheresTheme.accent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 2: Permissions

    private var permissionsStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("What should we scan?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("We'll analyze your data to create personalized life spheres.\nOnly summaries are sent to AI — never full content.")
                    .font(.system(size: 14))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Source toggles
            VStack(spacing: 12) {
                SourceToggleCard(
                    icon: "calendar",
                    title: "Calendar",
                    subtitle: "Events and schedules from the last 30 days",
                    isEnabled: $setupService.calendarEnabled
                )

                ForEach(availableSources, id: \.self) { source in
                    SourceToggleCard(
                        icon: source.icon,
                        title: source.rawValue,
                        subtitle: sourceSubtitle(source),
                        isEnabled: Binding(
                            get: { setupService.enabledSources.contains(source) },
                            set: { enabled in
                                if enabled {
                                    setupService.enabledSources.insert(source)
                                } else {
                                    setupService.enabledSources.remove(source)
                                }
                            }
                        )
                    )
                }
            }
            .frame(maxWidth: 400)

            Spacer()

            HStack(spacing: 16) {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .welcome
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(SpheresTheme.textSecondary)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .scanning
                    }
                    Task {
                        await setupService.performFullScan()
                        if setupService.scanPhase == .complete {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = .review
                            }
                        }
                    }
                }) {
                    Text("Scan My Mac")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(SpheresTheme.accent)
                        )
                }
                .buttonStyle(.plain)

                Button("Skip, set up manually") {
                    finishWithManualSetup()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.textTertiary)
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 40)
    }

    private var availableSources: [TaskSource] {
        [.reminders, .notes, .appleMail, .voiceMemos, .iMessage]
    }

    private func sourceSubtitle(_ source: TaskSource) -> String {
        switch source {
        case .reminders: return "Your Apple Reminders lists"
        case .notes: return "Task-like items from Apple Notes"
        case .appleMail: return "Recent email subjects and senders"
        case .voiceMemos: return "Transcribed voice memo content"
        case .iMessage: return "Requires Full Disk Access"
        default: return ""
        }
    }

    // MARK: - Step 3: Scanning

    private var scanningStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(SpheresTheme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)

                if setupService.scanPhase == .analyzingWithAI {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundColor(SpheresTheme.accent)
                        .symbolEffect(.pulse)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(SpheresTheme.accent)
                        .symbolEffect(.bounce, value: setupService.scanProgress)
                }
            }

            VStack(spacing: 8) {
                Text(setupService.scanPhase == .analyzingWithAI ? "AI is analyzing your life..." : "Scanning your Mac...")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text(setupService.currentSourceLabel)
                    .font(.system(size: 14))
                    .foregroundColor(SpheresTheme.textSecondary)
            }

            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: setupService.scanProgress)
                    .progressViewStyle(.linear)
                    .tint(SpheresTheme.accent)
                    .frame(maxWidth: 300)

                Text("\(Int(setupService.scanProgress * 100))%")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(SpheresTheme.textTertiary)
            }

            // Completed sources
            if !setupService.completedSources.isEmpty {
                VStack(spacing: 6) {
                    ForEach(setupService.completedSources, id: \.self) { source in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text(source)
                                .font(.system(size: 13))
                                .foregroundColor(SpheresTheme.textSecondary)
                        }
                    }
                }
            }

            // Error state
            if case .failed(let reason) = setupService.scanPhase {
                VStack(spacing: 12) {
                    Text(reason == "notEnoughData" ? "Not enough data found" : "Something went wrong")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)

                    if let error = setupService.scanError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Set up manually instead") {
                        finishWithManualSetup()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(SpheresTheme.accent)
                }
            }

            Spacer()

            Text("This usually takes 15-30 seconds")
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.textTertiary)
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 4: Review

    private var reviewStep: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text("Here's what we found")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                if let insights = setupService.aiGeneratedSetup?.insights, !insights.isEmpty {
                    Text(insights)
                        .font(.system(size: 14))
                        .foregroundColor(SpheresTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 24)

            // Sphere list
            if let setup = setupService.aiGeneratedSetup {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(setup.spheres.enumerated()), id: \.element.id) { index, sphere in
                            SphereReviewCard(
                                sphere: sphere,
                                onToggle: { enabled in
                                    setupService.aiGeneratedSetup?.spheres[index].isEnabled = enabled
                                },
                                onRename: { newName in
                                    setupService.aiGeneratedSetup?.spheres[index].name = newName
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 16)
                }
            }

            // Bottom bar
            HStack(spacing: 16) {
                Button("Back to Permissions") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .permissions
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(SpheresTheme.textSecondary)

                Spacer()

                if let setup = setupService.aiGeneratedSetup {
                    let enabledCount = setup.spheres.filter { $0.isEnabled }.count
                    let taskCount = setup.spheres.filter { $0.isEnabled }.flatMap { $0.tasks.filter { $0.isEnabled } }.count

                    Text("\(enabledCount) spheres, \(taskCount) tasks")
                        .font(.system(size: 13))
                        .foregroundColor(SpheresTheme.textTertiary)
                }

                Button(action: finishSmartSetup) {
                    Text("Looks great!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(SpheresTheme.accent)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .background(SpheresTheme.surface)
        }
    }

    // MARK: - Finish Actions

    private func finishSmartSetup() {
        guard let setup = setupService.aiGeneratedSetup else { return }

        // Create user profile
        let profile = DataManager.shared.createUserProfile(modelContext: modelContext)
        profile.displayName = userName

        // Materialize AI-generated spheres and tasks
        setupService.materialize(setup, modelContext: modelContext)

        // Load personalization
        PersonalizationService.shared.loadProfile(modelContext: modelContext)
        if !userName.isEmpty {
            let values = setup.suggestedValues.compactMap { SchwartzValue(rawValue: $0) }
            PersonalizationService.shared.seedFromOnboarding(
                name: userName,
                coreValues: values,
                style: .supportive
            )
        }

        // Mark onboarding complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(true, forKey: "hasUsedSmartSetup")
        UserDefaults.standard.set(true, forKey: "hasCleanedDefaultSpheres")
        UserDefaults.standard.set(true, forKey: "permission.calendar")
        UserDefaults.standard.set(true, forKey: "permission.aiProcessing")

        try? modelContext.save()
        isPresented = false
    }

    private func finishWithManualSetup() {
        // Create basic profile and let user add spheres manually
        let profile = DataManager.shared.createUserProfile(modelContext: modelContext)
        profile.displayName = userName

        PersonalizationService.shared.loadProfile(modelContext: modelContext)

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(true, forKey: "hasCleanedDefaultSpheres")

        try? modelContext.save()
        isPresented = false
    }
}

// MARK: - Source Toggle Card

struct SourceToggleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isEnabled ? SpheresTheme.accent : SpheresTheme.textTertiary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(SpheresTheme.textTertiary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isEnabled ? SpheresTheme.accent.opacity(0.05) : SpheresTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isEnabled ? SpheresTheme.accent.opacity(0.2) : SpheresTheme.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - Sphere Review Card

struct SphereReviewCard: View {
    let sphere: AIGeneratedSetup.GeneratedSphere
    var onToggle: (Bool) -> Void
    var onRename: (String) -> Void

    @State private var isExpanded = false
    @State private var editingName: String

    init(sphere: AIGeneratedSetup.GeneratedSphere, onToggle: @escaping (Bool) -> Void, onRename: @escaping (String) -> Void) {
        self.sphere = sphere
        self.onToggle = onToggle
        self.onRename = onRename
        self._editingName = State(initialValue: sphere.name)
    }

    private var sphereColor: Color {
        Color(red: sphere.color.r, green: sphere.color.g, blue: sphere.color.b)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Sphere icon
                ZStack {
                    Circle()
                        .fill(sphereColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: sphere.icon)
                        .font(.system(size: 18))
                        .foregroundColor(sphereColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Sphere name", text: $editingName, onCommit: {
                        onRename(editingName)
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(sphere.isEnabled ? SpheresTheme.textPrimary : SpheresTheme.textTertiary)

                    Text(sphere.description)
                        .font(.system(size: 12))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Task count
                Text("\(sphere.tasks.count) tasks")
                    .font(.system(size: 12))
                    .foregroundColor(SpheresTheme.textTertiary)

                // Expand toggle
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
                .buttonStyle(.plain)

                // Enable/disable
                Toggle("", isOn: Binding(
                    get: { sphere.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(16)

            // Expanded task list
            if isExpanded && sphere.isEnabled {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sphere.tasks) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(sphereColor.opacity(0.4))
                                .frame(width: 6, height: 6)

                            Text(task.content)
                                .font(.system(size: 13))
                                .foregroundColor(SpheresTheme.textSecondary)
                                .lineLimit(1)

                            Spacer()

                            // Priority badge
                            Text("P\(task.importance)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(SpheresTheme.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(SpheresTheme.surface)
                                )

                            // Source badge
                            Text(task.source)
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.textTertiary)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(sphere.isEnabled ? SpheresTheme.surface : SpheresTheme.surface.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(sphere.isEnabled ? sphereColor.opacity(0.3) : SpheresTheme.border, lineWidth: 1)
                )
        )
        .opacity(sphere.isEnabled ? 1.0 : 0.6)
    }
}
