//
//  UnifiedOnboardingFlow.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  10-step personalized onboarding with values quiz and sphere setup
//

import SwiftUI
import SwiftData

// MARK: - Unified Onboarding Steps

enum UnifiedOnboardingStep: Int, CaseIterable {
    case welcome = 0
    case valuesIntro = 1
    case valuesQuiz = 2
    case valuesResults = 3
    case sphereSuggestions = 4
    case sphereCustomization = 5
    case dataSources = 6
    case privacyPromise = 7
    case energyProfile = 8
    case complete = 9

    var progress: CGFloat {
        CGFloat(rawValue) / CGFloat(Self.allCases.count - 1)
    }

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .valuesIntro: return "Your Values"
        case .valuesQuiz: return "Quiz"
        case .valuesResults: return "Results"
        case .sphereSuggestions: return "Spheres"
        case .sphereCustomization: return "Customize"
        case .dataSources: return "Sources"
        case .privacyPromise: return "Privacy"
        case .energyProfile: return "Energy"
        case .complete: return "Done"
        }
    }
}

// MARK: - Unified Onboarding Flow

struct UnifiedOnboardingFlow: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    // State
    @State private var currentStep: UnifiedOnboardingStep = .welcome
    @StateObject private var quizEngine = ValuesQuizEngine()
    @StateObject private var privacySettings = PrivacySettings()

    // User data collected during onboarding
    @State private var userName: String = ""
    @State private var valuesScores: [SchwartzValue: Double] = [:]
    @State private var topValues: [SchwartzValue] = []
    @State private var selectedSpheres: [SphereSetup] = []
    @State private var communicationStyle: CommunicationTone = .supportive
    @State private var verbosity: VerbosityLevel = .concise
    @State private var skipEnergyProfile: Bool = false
    @State private var showEnergyOnboarding: Bool = false
    @AppStorage("hasCompletedEnergyOnboarding") private var hasCompletedEnergy = false

    var body: some View {
        ZStack {
            SpheresTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator (segmented capsules)
                OnboardingProgressIndicator(
                    currentStep: currentStep.rawValue,
                    totalSteps: UnifiedOnboardingStep.allCases.count
                )
                .padding(.horizontal, 40)
                .padding(.top, 24)

                // Content - no sliding transitions, instant page switch
                Group {
                    switch currentStep {
                    case .welcome:
                        WelcomeOnboardingStep(userName: $userName)
                    case .valuesIntro:
                        ValuesIntroStep()
                    case .valuesQuiz:
                        ValuesQuizStep(engine: quizEngine, onComplete: handleQuizComplete)
                    case .valuesResults:
                        ValuesResultsOnboardingStep(
                            scores: valuesScores,
                            topValues: topValues
                        )
                    case .sphereSuggestions:
                        SphereSuggestionsStep(
                            topValues: topValues,
                            selectedSpheres: $selectedSpheres
                        )
                    case .sphereCustomization:
                        SphereCustomizationStep(spheres: $selectedSpheres)
                    case .dataSources:
                        DataSourcesStep(settings: privacySettings, onSkip: goNext)
                    case .privacyPromise:
                        PrivacyPromiseOnboardingStep()
                    case .energyProfile:
                        EnergyProfileStep(
                            skipProfile: $skipEnergyProfile,
                            showEnergyOnboarding: $showEnergyOnboarding,
                            onSkip: {
                                skipEnergyProfile = true
                                goNext()
                            }
                        )
                    case .complete:
                        CompleteOnboardingStep(
                            userName: userName,
                            topValues: topValues,
                            sphereCount: selectedSpheres.count
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Navigation buttons
                OnboardingNavigation(
                    currentStep: currentStep,
                    canGoBack: currentStep != .welcome && currentStep != .valuesQuiz,
                    isQuizInProgress: currentStep == .valuesQuiz && !quizEngine.isComplete,
                    onBack: goBack,
                    onNext: goNext
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
        }
        .frame(width: 700, height: 600)
        .sheet(isPresented: $showEnergyOnboarding) {
            EnergyProfilingSheet(isPresented: $showEnergyOnboarding)
        }
    }

    // MARK: - Navigation

    private func goBack() {
        guard let previous = UnifiedOnboardingStep(rawValue: currentStep.rawValue - 1) else { return }

        // Skip valuesQuiz when going back (go to intro instead)
        if currentStep == .valuesResults {
            currentStep = .valuesIntro
            quizEngine.reset()
            return
        }

        currentStep = previous
    }

    private func goNext() {
        // Handle special cases
        switch currentStep {
        case .valuesQuiz:
            // Quiz handles its own completion
            return
        case .privacyPromise:
            // Skip energy profile in onboarding - it's now in Schedule tab
            currentStep = .complete
            return
        case .energyProfile:
            // Energy profile is now accessed from Schedule tab, not onboarding
            // This case shouldn't be reached, but handle it gracefully
            break
        case .complete:
            finishOnboarding()
            return
        default:
            break
        }

        guard let next = UnifiedOnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    private func handleQuizComplete() {
        valuesScores = quizEngine.calculateResults()
        topValues = quizEngine.topValues(count: 5)
        currentStep = .valuesResults
    }

    // MARK: - Finish Onboarding

    private func finishOnboarding() {
        // Create user profile
        let profile = DataManager.shared.createUserProfile(modelContext: modelContext)

        // Set basic info
        profile.displayName = userName
        profile.valuesScores = valuesScores
        profile.coreValues = topValues
        profile.tone = communicationStyle
        profile.verbosity = verbosity

        // Create spheres
        for setup in selectedSpheres {
            let sphere = SphereModel(
                name: setup.name,
                icon: setup.icon,
                color: setup.color,
                description: setup.description,
                priorityRank: setup.rank
            )
            modelContext.insert(sphere)
        }

        // Seed initial memories
        PersonalizationService.shared.loadProfile(modelContext: modelContext)
        PersonalizationService.shared.seedFromOnboarding(
            name: userName.isEmpty ? nil : userName,
            coreValues: topValues,
            style: communicationStyle
        )

        // Save permissions
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(true, forKey: "hasCompletedValuesQuiz")
        UserDefaults.standard.set(privacySettings.iMessageEnabled, forKey: "permission.imessage")
        UserDefaults.standard.set(privacySettings.gmailEnabled, forKey: "permission.gmail")
        UserDefaults.standard.set(privacySettings.calendarEnabled, forKey: "permission.calendar")
        UserDefaults.standard.set(privacySettings.aiProcessingEnabled, forKey: "permission.aiProcessing")

        try? modelContext.save()

        isPresented = false
    }
}

// MARK: - Progress Indicator

struct OnboardingProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? SpheresTheme.accent : SpheresTheme.surface)
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - Navigation Buttons

struct OnboardingNavigation: View {
    let currentStep: UnifiedOnboardingStep
    let canGoBack: Bool
    let isQuizInProgress: Bool
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if canGoBack {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(GhostButtonStyle())
            }

            Spacer()

            if !isQuizInProgress {
                Button(action: onNext) {
                    HStack(spacing: 8) {
                        Text(buttonText)
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: currentStep == .complete ? "checkmark" : "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(SpheresTheme.accent)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var buttonText: String {
        switch currentStep {
        case .complete: return "Get Started"
        case .valuesIntro: return "Start Quiz"
        case .energyProfile: return "Set Up Energy"
        default: return "Continue"
        }
    }
}

// MARK: - Step 1: Welcome

struct WelcomeOnboardingStep: View {
    @Binding var userName: String

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            ZStack {
                Circle()
                    .fill(SpheresTheme.accent.opacity(0.1))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(SpheresTheme.accent.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 44))
                    .foregroundColor(SpheresTheme.accent)
            }

            VStack(spacing: 12) {
                Text("Welcome to Spheres")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("Let's set up your personal life manager.\nThis will only take a few minutes.")
                    .font(.system(size: 15))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("What should I call you?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                TextField("Your name (optional)", text: $userName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(SpheresTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(SpheresTheme.border, lineWidth: 1)
                    )
            }
            .frame(width: 280)

            // Privacy badge
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                Text("Privacy-first design")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.1))
            )

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Step 2: Values Intro

struct ValuesIntroStep: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(SpheresTheme.accent)

            VStack(spacing: 12) {
                Text("What Matters to You?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("Next, we'll ask a few questions to understand\nwhat you value most in life.")
                    .font(.system(size: 15))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                ValuesIntroRow(
                    icon: "sparkles",
                    title: "Personalized Experience",
                    description: "Your spheres will reflect what matters to you"
                )

                ValuesIntroRow(
                    icon: "brain.head.profile",
                    title: "Smarter Suggestions",
                    description: "AI will prioritize tasks aligned with your values"
                )

                ValuesIntroRow(
                    icon: "clock.arrow.circlepath",
                    title: "Just 2 Minutes",
                    description: "7 quick scenarios - no right or wrong answers"
                )
            }
            .padding(.horizontal, 40)

            Text("Based on Schwartz Theory of Basic Human Values,\nvalidated across 80+ countries")
                .font(.system(size: 11))
                .foregroundColor(SpheresTheme.textTertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct ValuesIntroRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(SpheresTheme.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(SpheresTheme.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SpheresTheme.surface)
        )
    }
}

// MARK: - Step 3: Values Quiz (Embedded)

struct ValuesQuizStep: View {
    @ObservedObject var engine: ValuesQuizEngine
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Quiz progress
            ValuesProgressBar(progress: engine.progress, totalSteps: engine.questions.count)
                .padding(.horizontal, 60)
                .padding(.top, 20)

            if let question = engine.currentQuestion {
                ValuesQuestionView(
                    question: question,
                    questionNumber: engine.currentQuestionIndex + 1,
                    totalQuestions: engine.questions.count,
                    onSelect: { option in
                        engine.selectOption(option)
                        if engine.isComplete {
                            onComplete()
                        }
                    },
                    onBack: engine.currentQuestionIndex > 0 ? {
                        engine.goBack()
                    } : nil
                )
            }
        }
    }
}

// MARK: - Step 4: Values Results

struct ValuesResultsOnboardingStep: View {
    let scores: [SchwartzValue: Double]
    let topValues: [SchwartzValue]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(SpheresTheme.accent)

                    Text("Your Core Values")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(SpheresTheme.textPrimary)

                    Text("Here's what matters most to you")
                        .font(.subheadline)
                        .foregroundColor(SpheresTheme.textSecondary)
                }

                // Top 3 values
                VStack(spacing: 12) {
                    ForEach(Array(topValues.prefix(3).enumerated()), id: \.element) { index, value in
                        ValueResultCard(
                            value: value,
                            score: scores[value] ?? 0,
                            rank: index + 1
                        )
                    }
                }
                .padding(.horizontal, 60)

                // Brief explanation
                Text("We'll use these values to suggest spheres and prioritize your tasks.")
                    .font(.caption)
                    .foregroundColor(SpheresTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)

                Spacer(minLength: 20)
            }
        }
    }
}

// MARK: - Step 5: Sphere Suggestions

struct SphereSetup: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
    var color: Color
    var description: String
    var rank: Int
    var isSelected: Bool = true
}

struct SphereSuggestionsStep: View {
    let topValues: [SchwartzValue]
    @Binding var selectedSpheres: [SphereSetup]

    var suggestedSpheres: [SphereSetup] {
        var suggestions: [SphereSetup] = []
        var addedNames: Set<String> = []
        var rank = 1

        for value in topValues {
            for sphereName in value.suggestedSpheres {
                if !addedNames.contains(sphereName) {
                    addedNames.insert(sphereName)
                    suggestions.append(SphereSetup(
                        name: sphereName,
                        icon: sphereIcon(for: sphereName),
                        color: value.color,
                        description: sphereDescription(for: sphereName),
                        rank: rank
                    ))
                    rank += 1
                    if suggestions.count >= 6 { break }
                }
            }
            if suggestions.count >= 6 { break }
        }

        return suggestions
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            VStack(spacing: 8) {
                Text("Your Suggested Spheres")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("Based on your values, here are spheres to organize your life")
                    .font(.subheadline)
                    .foregroundColor(SpheresTheme.textSecondary)
            }

            // Sphere grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(selectedSpheres.indices, id: \.self) { index in
                    SphereSelectionCard(
                        setup: selectedSpheres[index],
                        isSelected: selectedSpheres[index].isSelected,
                        onToggle: {
                            selectedSpheres[index].isSelected.toggle()
                        }
                    )
                }
            }
            .padding(.horizontal, 40)

            // Add custom sphere
            Button(action: addCustomSphere) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Custom Sphere")
                }
                .font(.subheadline)
                .foregroundColor(SpheresTheme.accent)
            }
            .buttonStyle(.plain)

            Text("You can add, remove, or rename spheres later")
                .font(.caption)
                .foregroundColor(SpheresTheme.textTertiary)

            Spacer(minLength: 20)
        }
        .onAppear {
            if selectedSpheres.isEmpty {
                selectedSpheres = suggestedSpheres
            }
        }
    }

    private func addCustomSphere() {
        selectedSpheres.append(SphereSetup(
            name: "New Sphere",
            icon: "circle.fill",
            color: SpheresTheme.accent,
            description: "",
            rank: selectedSpheres.count + 1
        ))
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
        case "personal growth": return "arrow.up.circle.fill"
        case "adventure": return "airplane"
        case "fun", "fun/recreation": return "gamecontroller.fill"
        case "community": return "globe.americas.fill"
        default: return "circle.fill"
        }
    }

    private func sphereDescription(for name: String) -> String {
        switch name.lowercased() {
        case "health": return "Fitness, nutrition, wellness"
        case "career": return "Work, professional growth"
        case "family": return "Parents, siblings, loved ones"
        case "education": return "Learning, courses, skills"
        case "creative": return "Art, music, writing"
        case "spirituality", "spiritual": return "Faith, meditation, inner peace"
        case "finances": return "Money, investments, budgeting"
        case "relationships": return "Friends, networking, community"
        case "personal growth": return "Self-improvement, habits"
        default: return ""
        }
    }
}

struct SphereSelectionCard: View {
    let setup: SphereSetup
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(setup.color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: setup.icon)
                        .font(.system(size: 22))
                        .foregroundColor(setup.color)
                }

                Text(setup.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? SpheresTheme.surfaceHover : SpheresTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? SpheresTheme.accent : SpheresTheme.border, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(
                Group {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(SpheresTheme.accent)
                            .offset(x: -8, y: 8)
                    }
                },
                alignment: .topTrailing
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 6: Sphere Customization

struct SphereCustomizationStep: View {
    @Binding var spheres: [SphereSetup]
    @State private var editingSphere: SphereSetup?

    var selectedSpheres: [SphereSetup] {
        spheres.filter { $0.isSelected }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            VStack(spacing: 8) {
                Text("Customize Your Spheres")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("Rename or reorder to match how you think about your life")
                    .font(.subheadline)
                    .foregroundColor(SpheresTheme.textSecondary)
            }

            // List of selected spheres
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(selectedSpheres.indices, id: \.self) { index in
                        if let sphereIndex = spheres.firstIndex(where: { $0.id == selectedSpheres[index].id }) {
                            SphereCustomizeRow(
                                sphere: $spheres[sphereIndex],
                                rank: index + 1
                            )
                        }
                    }
                }
                .padding(.horizontal, 60)
            }

            Text("Drag to reorder. Higher = more important.")
                .font(.caption)
                .foregroundColor(SpheresTheme.textTertiary)

            Spacer(minLength: 20)
        }
    }
}

struct SphereCustomizeRow: View {
    @Binding var sphere: SphereSetup
    let rank: Int
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .foregroundColor(SpheresTheme.textTertiary)
                .frame(width: 24)

            // Icon
            ZStack {
                Circle()
                    .fill(sphere.color.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: sphere.icon)
                    .foregroundColor(sphere.color)
            }

            // Name (editable)
            if isEditing {
                TextField("Sphere name", text: $sphere.name)
                    .textFieldStyle(.plain)
                    .onSubmit { isEditing = false }
            } else {
                Text(sphere.name)
                    .foregroundColor(SpheresTheme.textPrimary)
            }

            Spacer()

            // Edit button
            Button(action: { isEditing.toggle() }) {
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .foregroundColor(SpheresTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SpheresTheme.surface)
        )
    }
}

// MARK: - Step 7: Data Sources

struct DataSourcesStep: View {
    @ObservedObject var settings: PrivacySettings
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "app.badge.checkmark.fill")
                .font(.system(size: 44))
                .foregroundColor(SpheresTheme.accent)

            Text("Collect Tasks Automatically")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(SpheresTheme.textPrimary)

            Text("Spheres can scan your apps for tasks.\nEverything is processed on your device.")
                .font(.system(size: 14))
                .foregroundColor(SpheresTheme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                PermissionToggleCard(
                    icon: "envelope.fill",
                    iconColor: .blue,
                    title: "Apple Mail",
                    description: "Find action items in emails",
                    privacyNote: "Processed locally via AppleScript",
                    isEnabled: $settings.gmailEnabled
                )

                PermissionToggleCard(
                    icon: "note.text",
                    iconColor: .yellow,
                    title: "Notes",
                    description: "Extract TODOs from your notes",
                    privacyNote: "Processed locally via AppleScript",
                    isEnabled: $settings.calendarEnabled
                )

                PermissionToggleCard(
                    icon: "checkmark.circle.fill",
                    iconColor: .orange,
                    title: "Reminders",
                    description: "Import from Apple Reminders",
                    privacyNote: "Via EventKit, stays on device",
                    isEnabled: $settings.aiProcessingEnabled
                )
            }
            .padding(.horizontal, 40)

            Button("Skip for now") {
                settings.gmailEnabled = false
                settings.calendarEnabled = false
                settings.aiProcessingEnabled = false
                onSkip()
            }
            .buttonStyle(GhostButtonStyle())

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Step 8: Privacy Promise

struct PrivacyPromiseOnboardingStep: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundColor(SpheresTheme.accent)

            Text("Our Privacy Promise")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(SpheresTheme.textPrimary)

            VStack(spacing: 16) {
                PrivacyPromiseRow(
                    icon: "iphone",
                    title: "On-Device Analysis",
                    description: "Your data never leaves your Mac"
                )

                PrivacyPromiseRow(
                    icon: "eye.slash.fill",
                    title: "No Cloud Required",
                    description: "AI runs locally - no API calls for analysis"
                )

                PrivacyPromiseRow(
                    icon: "arrow.up.bin.fill",
                    title: "Delete Anytime",
                    description: "Remove all data instantly in Settings"
                )
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Step 9: Energy Profile

struct EnergyProfileStep: View {
    @Binding var skipProfile: Bool
    @Binding var showEnergyOnboarding: Bool
    let onSkip: () -> Void
    @AppStorage("hasCompletedEnergyOnboarding") private var hasCompletedEnergy = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "bolt.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow)

            Text("Energy-Aware Scheduling")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(SpheresTheme.textPrimary)

            Text("Spheres can learn your energy patterns and schedule\ntasks when you're most focused.")
                .font(.system(size: 14))
                .foregroundColor(SpheresTheme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                EnergyFeatureRow(icon: "sun.max.fill", text: "Identifies your peak focus hours")
                EnergyFeatureRow(icon: "moon.fill", text: "Suggests creative work during energy dips")
                EnergyFeatureRow(icon: "calendar", text: "Analyzes your calendar history")
            }
            .padding(.horizontal, 60)

            if hasCompletedEnergy {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Energy profile already set up")
                        .foregroundColor(SpheresTheme.textSecondary)
                }
            }

            Button("Skip for now") {
                onSkip()
            }
            .buttonStyle(GhostButtonStyle())

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct EnergyFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.yellow)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(SpheresTheme.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Step 10: Complete

struct CompleteOnboardingStep: View {
    let userName: String
    let topValues: [SchwartzValue]
    let sphereCount: Int

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
            }

            VStack(spacing: 8) {
                Text(userName.isEmpty ? "You're All Set!" : "Welcome, \(userName)!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("Your personalized life manager is ready")
                    .font(.subheadline)
                    .foregroundColor(SpheresTheme.textSecondary)
            }

            // Summary
            VStack(spacing: 12) {
                if !topValues.isEmpty {
                    SummaryRow(
                        icon: "heart.fill",
                        text: "Values: \(topValues.prefix(3).map { $0.rawValue }.joined(separator: ", "))"
                    )
                }

                SummaryRow(
                    icon: "circle.grid.2x2.fill",
                    text: "\(sphereCount) spheres created"
                )

                SummaryRow(
                    icon: "sparkles",
                    text: "AI will learn your preferences over time"
                )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SpheresTheme.surface)
            )
            .padding(.horizontal, 60)

            Text("I'll get to know you better as we work together.")
                .font(.caption)
                .foregroundColor(SpheresTheme.textTertiary)
                .italic()

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct SummaryRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(SpheresTheme.accent)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(SpheresTheme.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    UnifiedOnboardingFlow(isPresented: .constant(true))
        .modelContainer(for: [SphereModel.self, OpenLoopModel.self, UserProfileModel.self])
}
#endif
