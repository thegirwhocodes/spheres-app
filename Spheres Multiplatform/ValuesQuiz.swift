//
//  ValuesQuiz.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Life Orientations Quiz - A dimensional model for understanding life priorities
//
//  Research Basis:
//  - Schwartz Theory structure (tensions between opposing values)
//  - Harvard Human Flourishing Program (Tyler VanderWeele)
//  - Time Perspective Theory (Zimbardo)
//  - Self-Determination Theory (Ryan & Deci)
//
//  Biblical Basis:
//  - Martha vs Mary (Luke 10:38-42) → Being ↔ Doing
//  - Work vs Trust (Prov 10:4 + Matt 6:25-34)
//  - Family vs Mission (1 Tim 5:8 + Luke 14:26)
//  - Body as temple (1 Cor 6:19) + Self-denial (Luke 9:23)
//

import SwiftUI

// MARK: - Quiz Data Model

struct OrientationQuestion: Identifiable {
    let id = UUID()
    let scenario: String
    let dimension: OrientationDimension
    let options: [OrientationOption]
    let allowsCustomAnswer: Bool
}

enum OrientationDimension: String {
    case renewal     // Solitude ↔ Community
    case expression  // Being ↔ Doing
    case care        // Inner ↔ Outer
    case time        // Present ↔ Future
}

struct OrientationOption: Identifiable {
    let id = UUID()
    let text: String
    let dimensionValue: Double  // 0.0 = left pole, 1.0 = right pole
    let lifeAreas: [LifeArea: Double]  // Secondary effect on life areas

    init(text: String, dimensionValue: Double, lifeAreas: [(LifeArea, Double)] = []) {
        self.text = text
        self.dimensionValue = dimensionValue
        self.lifeAreas = Dictionary(uniqueKeysWithValues: lifeAreas)
    }
}

// MARK: - Quiz Questions (5 Dimensional Trade-offs)

/// Questions that reveal position on each dimension through natural trade-offs
let orientationQuizQuestions: [OrientationQuestion] = [

    // DIMENSION 1: Renewal Source (Solitude ↔ Community)
    // "Where do you find renewal?" - Biblical: Jesus withdrew to pray (Luke 5:16) vs Hebrews 10:25
    OrientationQuestion(
        scenario: "After a draining week, what restores your energy?",
        dimension: .renewal,
        options: [
            OrientationOption(
                text: "Quiet time alone — reading, praying, or just being still",
                dimensionValue: 0.15,
                lifeAreas: [(.faith, 0.4), (.health, 0.3), (.growth, 0.2)]
            ),
            OrientationOption(
                text: "Time with one or two close people who really know me",
                dimensionValue: 0.4,
                lifeAreas: [(.family, 0.5), (.health, 0.2)]
            ),
            OrientationOption(
                text: "Being around people — friends, family, community",
                dimensionValue: 0.75,
                lifeAreas: [(.family, 0.3), (.community, 0.4)]
            ),
            OrientationOption(
                text: "Serving or helping others — it fills me up",
                dimensionValue: 0.9,
                lifeAreas: [(.community, 0.5), (.faith, 0.2)]
            )
        ],
        allowsCustomAnswer: true
    ),

    // DIMENSION 2: Expression Mode (Being ↔ Doing)
    // "How do you express what matters?" - Biblical: Martha vs Mary (Luke 10:38-42)
    OrientationQuestion(
        scenario: "When you care deeply about something, you tend to...",
        dimension: .expression,
        options: [
            OrientationOption(
                text: "Reflect on it — pray, journal, or think deeply",
                dimensionValue: 0.1,
                lifeAreas: [(.faith, 0.4), (.growth, 0.3)]
            ),
            OrientationOption(
                text: "Learn more about it — read, study, understand",
                dimensionValue: 0.35,
                lifeAreas: [(.growth, 0.5), (.faith, 0.2)]
            ),
            OrientationOption(
                text: "Talk about it with others and share your perspective",
                dimensionValue: 0.6,
                lifeAreas: [(.community, 0.3), (.family, 0.2)]
            ),
            OrientationOption(
                text: "Take action — do something tangible about it",
                dimensionValue: 0.9,
                lifeAreas: [(.work, 0.4), (.community, 0.3)]
            )
        ],
        allowsCustomAnswer: true
    ),

    // DIMENSION 3: Care Focus (Inner Circle ↔ Outer Circle)
    // "Who do you focus your energy on?" - Biblical: 1 Tim 5:8 vs Matthew 28:19
    OrientationQuestion(
        scenario: "With limited time and energy, you prioritize...",
        dimension: .care,
        options: [
            OrientationOption(
                text: "Taking care of yourself so you can show up fully",
                dimensionValue: 0.1,
                lifeAreas: [(.health, 0.5), (.growth, 0.2)]
            ),
            OrientationOption(
                text: "Your immediate family and closest relationships",
                dimensionValue: 0.3,
                lifeAreas: [(.family, 0.6), (.finances, 0.2)]
            ),
            OrientationOption(
                text: "Your broader community — friends, church, neighbors",
                dimensionValue: 0.65,
                lifeAreas: [(.community, 0.5), (.faith, 0.2)]
            ),
            OrientationOption(
                text: "Making an impact beyond your immediate circle",
                dimensionValue: 0.9,
                lifeAreas: [(.community, 0.4), (.work, 0.3), (.faith, 0.2)]
            )
        ],
        allowsCustomAnswer: true
    ),

    // DIMENSION 4: Time Horizon (Present ↔ Future)
    // "What timeframe drives you?" - Biblical: Matt 6:34 vs Proverbs 21:5
    OrientationQuestion(
        scenario: "When making decisions, you think most about...",
        dimension: .time,
        options: [
            OrientationOption(
                text: "What brings peace and joy right now",
                dimensionValue: 0.15,
                lifeAreas: [(.health, 0.4), (.family, 0.3)]
            ),
            OrientationOption(
                text: "What's best for the next few months",
                dimensionValue: 0.4,
                lifeAreas: [(.work, 0.3), (.health, 0.2), (.family, 0.2)]
            ),
            OrientationOption(
                text: "Building something that lasts for years",
                dimensionValue: 0.7,
                lifeAreas: [(.work, 0.4), (.finances, 0.4), (.family, 0.2)]
            ),
            OrientationOption(
                text: "What matters in light of eternity",
                dimensionValue: 0.95,
                lifeAreas: [(.faith, 0.5), (.community, 0.2), (.growth, 0.2)]
            )
        ],
        allowsCustomAnswer: true
    ),

    // COMBINED: Trade-off scenario revealing overall profile
    // "When priorities compete, what wins?" - Real-life integration
    OrientationQuestion(
        scenario: "A friend needs help on the same evening you planned for rest. You typically...",
        dimension: .care,  // Primary dimension, but affects others too
        options: [
            OrientationOption(
                text: "Honor your rest — you can't pour from an empty cup",
                dimensionValue: 0.15,
                lifeAreas: [(.health, 0.5), (.growth, 0.2)]
            ),
            OrientationOption(
                text: "Depends on who it is — closest friends, yes; acquaintances, maybe later",
                dimensionValue: 0.4,
                lifeAreas: [(.family, 0.4), (.health, 0.2)]
            ),
            OrientationOption(
                text: "Go help — relationships matter more than a quiet evening",
                dimensionValue: 0.75,
                lifeAreas: [(.community, 0.4), (.family, 0.3)]
            ),
            OrientationOption(
                text: "Pray about it first, then decide based on what feels right",
                dimensionValue: 0.5,
                lifeAreas: [(.faith, 0.5), (.community, 0.2)]
            )
        ],
        allowsCustomAnswer: true
    )
]

// MARK: - Quiz Logic

class OrientationQuizEngine: ObservableObject {
    @Published var currentQuestionIndex = 0
    @Published var answers: [UUID: OrientationOption] = [:]
    @Published var customAnswers: [UUID: String] = [:]
    @Published var isComplete = false

    var questions: [OrientationQuestion] { orientationQuizQuestions }

    var currentQuestion: OrientationQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progress: Double {
        Double(currentQuestionIndex) / Double(questions.count)
    }

    func selectOption(_ option: OrientationOption) {
        guard let question = currentQuestion else { return }
        answers[question.id] = option

        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
        } else {
            isComplete = true
        }
    }

    func submitCustomAnswer(_ text: String) {
        guard let question = currentQuestion, !text.isEmpty else { return }
        customAnswers[question.id] = text

        // Custom answers default to middle of spectrum + Growth boost
        let customOption = OrientationOption(
            text: text,
            dimensionValue: 0.5,
            lifeAreas: [(.growth, 0.4), (.faith, 0.2)]
        )
        answers[question.id] = customOption

        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
        } else {
            isComplete = true
        }
    }

    func goBack() {
        if currentQuestionIndex > 0 {
            currentQuestionIndex -= 1
        }
    }

    /// Calculates the 4-dimensional orientation profile
    func calculateOrientationProfile() -> LifeOrientationProfile {
        var profile = LifeOrientationProfile()

        // Track scores per dimension
        var dimensionScores: [OrientationDimension: [Double]] = [
            .renewal: [],
            .expression: [],
            .care: [],
            .time: []
        ]

        // Collect scores from answers
        for (questionId, option) in answers {
            if let question = questions.first(where: { $0.id == questionId }) {
                dimensionScores[question.dimension]?.append(option.dimensionValue)
            }
        }

        // Average scores for each dimension
        if let renewalScores = dimensionScores[.renewal], !renewalScores.isEmpty {
            profile.renewalSource = renewalScores.reduce(0, +) / Double(renewalScores.count)
        }
        if let expressionScores = dimensionScores[.expression], !expressionScores.isEmpty {
            profile.expressionMode = expressionScores.reduce(0, +) / Double(expressionScores.count)
        }
        if let careScores = dimensionScores[.care], !careScores.isEmpty {
            profile.careFocus = careScores.reduce(0, +) / Double(careScores.count)
        }
        if let timeScores = dimensionScores[.time], !timeScores.isEmpty {
            profile.timeHorizon = timeScores.reduce(0, +) / Double(timeScores.count)
        }

        return profile
    }

    /// Calculates life area scores based on both direct selections and orientation profile
    func calculateLifeAreaScores() -> [LifeArea: Double] {
        var scores: [LifeArea: Double] = [:]

        // Initialize with baseline
        for area in LifeArea.allCases {
            scores[area] = 0.2
        }

        // Add direct contributions from answers
        for (_, option) in answers {
            for (area, weight) in option.lifeAreas {
                scores[area, default: 0.2] += weight
            }
        }

        // Add orientation-based contributions
        let profile = calculateOrientationProfile()
        for area in LifeArea.allCases {
            let orientationBoost = area.priorityScore(for: profile) - 0.5
            scores[area, default: 0.2] += orientationBoost * 0.5
        }

        // Normalize to 0.0-1.0
        let maxScore = scores.values.max() ?? 1.0
        for area in LifeArea.allCases {
            scores[area] = max(0.1, min(1.0, (scores[area] ?? 0.2) / maxScore))
        }

        return scores
    }

    /// Returns life areas sorted by priority
    func prioritizedAreas() -> [LifeArea] {
        let scores = calculateLifeAreaScores()
        return scores.sorted { $0.value > $1.value }.map { $0.key }
    }

    func getCustomAnswers() -> [String] {
        return Array(customAnswers.values)
    }

    func reset() {
        currentQuestionIndex = 0
        answers = [:]
        customAnswers = [:]
        isComplete = false
    }
}

// MARK: - Legacy Support

class PriorityQuizEngine: ObservableObject {
    private let engine = OrientationQuizEngine()

    var currentQuestionIndex: Int { engine.currentQuestionIndex }
    var isComplete: Bool { engine.isComplete }
    var questions: [OrientationQuestion] { engine.questions }
    var currentQuestion: OrientationQuestion? { engine.currentQuestion }
    var progress: Double { engine.progress }

    func selectOption(_ option: PriorityOption) {
        // Convert to orientation option
        let orientationOption = OrientationOption(
            text: option.text,
            dimensionValue: 0.5,
            lifeAreas: option.areas.map { ($0.key, $0.value) }
        )
        engine.answers[engine.currentQuestion?.id ?? UUID()] = orientationOption
        if engine.currentQuestionIndex < engine.questions.count - 1 {
            engine.currentQuestionIndex += 1
        } else {
            engine.isComplete = true
        }
    }

    func calculateResults() -> [LifeArea: Double] {
        return engine.calculateLifeAreaScores()
    }

    func prioritizedAreas() -> [LifeArea] {
        return engine.prioritizedAreas()
    }

    func getCustomAnswers() -> [String] {
        return engine.getCustomAnswers()
    }

    func reset() {
        engine.reset()
    }
}

// Legacy types
struct PriorityQuestion: Identifiable {
    let id = UUID()
    let scenario: String
    let options: [PriorityOption]
    let allowsCustomAnswer: Bool
}

struct PriorityOption: Identifiable {
    let id = UUID()
    let text: String
    let areas: [LifeArea: Double]

    init(text: String, areas: [(LifeArea, Double)]) {
        self.text = text
        self.areas = Dictionary(uniqueKeysWithValues: areas)
    }
}

let priorityQuizQuestions: [PriorityQuestion] = []

// Legacy Schwartz support - wraps OrientationQuizEngine
class ValuesQuizEngine: ObservableObject {
    private let orientationEngine = OrientationQuizEngine()

    @Published var currentQuestionIndex = 0
    @Published var isComplete = false

    // Map orientation options to values options
    private var optionMapping: [UUID: OrientationOption] = [:]

    init() {
        // Build the option mapping
        for question in orientationEngine.questions {
            for option in question.options {
                optionMapping[option.id] = option
            }
        }
    }

    var questions: [ValuesQuestion] {
        orientationEngine.questions.map { orientationQ in
            ValuesQuestion(
                id: orientationQ.id,
                scenario: orientationQ.scenario,
                options: orientationQ.options.map { opt in
                    ValuesOption(
                        id: opt.id,
                        text: opt.text,
                        values: convertToSchwartzValues(opt.lifeAreas)
                    )
                }
            )
        }
    }

    var currentQuestion: ValuesQuestion? {
        guard let orientationQ = orientationEngine.currentQuestion else { return nil }
        return ValuesQuestion(
            id: orientationQ.id,
            scenario: orientationQ.scenario,
            options: orientationQ.options.map { opt in
                ValuesOption(
                    id: opt.id,
                    text: opt.text,
                    values: convertToSchwartzValues(opt.lifeAreas)
                )
            }
        )
    }

    var progress: Double { orientationEngine.progress }

    func selectOption(_ option: ValuesOption) {
        // Find the corresponding orientation option
        if let orientationOption = optionMapping[option.id] {
            orientationEngine.selectOption(orientationOption)
            currentQuestionIndex = orientationEngine.currentQuestionIndex
            isComplete = orientationEngine.isComplete
        }
    }

    func goBack() {
        orientationEngine.goBack()
        currentQuestionIndex = orientationEngine.currentQuestionIndex
    }

    func calculateResults() -> [SchwartzValue: Double] {
        let lifeAreaScores = orientationEngine.calculateLifeAreaScores()
        return convertLifeAreasToSchwartz(lifeAreaScores)
    }

    func topValues(count: Int = 3) -> [SchwartzValue] {
        let scores = calculateResults()
        return Array(scores.sorted { $0.value > $1.value }.prefix(count).map { $0.key })
    }

    func reset() {
        orientationEngine.reset()
        currentQuestionIndex = 0
        isComplete = false
    }

    // Convert life areas to Schwartz values
    private func convertToSchwartzValues(_ lifeAreas: [LifeArea: Double]) -> [SchwartzValue: Double] {
        var values: [SchwartzValue: Double] = [:]
        for (area, weight) in lifeAreas {
            switch area {
            case .faith:
                values[.tradition, default: 0] += weight
                values[.benevolence, default: 0] += weight * 0.5
            case .family:
                values[.benevolence, default: 0] += weight
                values[.security, default: 0] += weight * 0.5
            case .health:
                values[.security, default: 0] += weight
            case .work:
                values[.achievement, default: 0] += weight
            case .finances:
                values[.security, default: 0] += weight
                values[.power, default: 0] += weight * 0.5
            case .community:
                values[.universalism, default: 0] += weight
                values[.benevolence, default: 0] += weight * 0.5
            case .growth:
                values[.selfDirection, default: 0] += weight
                values[.stimulation, default: 0] += weight * 0.3
            }
        }
        return values
    }

    private func convertLifeAreasToSchwartz(_ lifeAreaScores: [LifeArea: Double]) -> [SchwartzValue: Double] {
        var scores: [SchwartzValue: Double] = [:]
        for value in SchwartzValue.allCases { scores[value] = 0.2 }

        for (area, score) in lifeAreaScores {
            switch area {
            case .faith:
                scores[.tradition, default: 0] += score
                scores[.benevolence, default: 0] += score * 0.5
            case .family:
                scores[.benevolence, default: 0] += score
                scores[.security, default: 0] += score * 0.5
            case .health:
                scores[.security, default: 0] += score
            case .work:
                scores[.achievement, default: 0] += score
            case .finances:
                scores[.security, default: 0] += score
                scores[.power, default: 0] += score * 0.5
            case .community:
                scores[.universalism, default: 0] += score
            case .growth:
                scores[.selfDirection, default: 0] += score
            }
        }

        // Normalize
        let max = scores.values.max() ?? 1.0
        for value in SchwartzValue.allCases {
            scores[value] = (scores[value] ?? 0) / max
        }
        return scores
    }
}

struct ValuesQuestion: Identifiable {
    let id: UUID
    let scenario: String
    let options: [ValuesOption]

    init(id: UUID = UUID(), scenario: String, options: [ValuesOption]) {
        self.id = id
        self.scenario = scenario
        self.options = options
    }
}

struct ValuesOption: Identifiable {
    let id: UUID
    let text: String
    let values: [SchwartzValue: Double]

    init(id: UUID = UUID(), text: String, values: [SchwartzValue: Double]) {
        self.id = id
        self.text = text
        self.values = values
    }

    init(text: String, values: [(SchwartzValue, Double)]) {
        self.id = UUID()
        self.text = text
        self.values = Dictionary(uniqueKeysWithValues: values)
    }
}

let valuesQuizQuestions: [ValuesQuestion] = []

// MARK: - Quiz UI Components

struct OrientationQuizView: View {
    @StateObject private var engine = OrientationQuizEngine()
    @Binding var isPresented: Bool
    var onComplete: (LifeOrientationProfile, [LifeArea: Double], [LifeArea], [String]) -> Void

    var body: some View {
        VStack(spacing: 0) {
            OrientationProgressBar(progress: engine.progress, totalSteps: engine.questions.count)
                .padding(.horizontal, 40)
                .padding(.top, 20)

            if engine.isComplete {
                OrientationResultsView(
                    profile: engine.calculateOrientationProfile(),
                    scores: engine.calculateLifeAreaScores(),
                    prioritizedAreas: engine.prioritizedAreas(),
                    onContinue: {
                        onComplete(
                            engine.calculateOrientationProfile(),
                            engine.calculateLifeAreaScores(),
                            engine.prioritizedAreas(),
                            engine.getCustomAnswers()
                        )
                        isPresented = false
                    },
                    onRetake: {
                        engine.reset()
                    }
                )
            } else if let question = engine.currentQuestion {
                OrientationQuestionView(
                    question: question,
                    questionNumber: engine.currentQuestionIndex + 1,
                    totalQuestions: engine.questions.count,
                    onSelect: { option in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            engine.selectOption(option)
                        }
                    },
                    onCustomAnswer: { text in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            engine.submitCustomAnswer(text)
                        }
                    },
                    onBack: engine.currentQuestionIndex > 0 ? {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            engine.goBack()
                        }
                    } : nil
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SpheresTheme.background)
    }
}

struct OrientationProgressBar: View {
    let progress: Double
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index < Int(progress * Double(totalSteps)) ? SpheresTheme.accent : SpheresTheme.surface)
                    .frame(height: 4)
            }
        }
    }
}

struct OrientationQuestionView: View {
    let question: OrientationQuestion
    let questionNumber: Int
    let totalQuestions: Int
    let onSelect: (OrientationOption) -> Void
    let onCustomAnswer: (String) -> Void
    let onBack: (() -> Void)?

    @State private var hoveredOption: UUID?
    @State private var showCustomField = false
    @State private var customText = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Question \(questionNumber) of \(totalQuestions)")
                .font(.caption)
                .foregroundColor(SpheresTheme.textTertiary)

            Text(question.scenario)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(SpheresTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(question.options) { option in
                        OrientationOptionCard(
                            option: option,
                            isHovered: hoveredOption == option.id,
                            onSelect: { onSelect(option) }
                        )
                        .onHover { isHovered in
                            hoveredOption = isHovered ? option.id : nil
                        }
                    }

                    if question.allowsCustomAnswer {
                        if showCustomField {
                            CustomAnswerField(
                                text: $customText,
                                onCancel: {
                                    showCustomField = false
                                    customText = ""
                                },
                                onSubmit: {
                                    if !customText.isEmpty {
                                        onCustomAnswer(customText)
                                    }
                                }
                            )
                        } else {
                            OtherOptionButton {
                                showCustomField = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
            }

            Spacer()

            if let onBack = onBack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundColor(SpheresTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
            }
        }
    }
}

struct OrientationOptionCard: View {
    let option: OrientationOption
    let isHovered: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(option.text)
                    .font(.body)
                    .foregroundColor(SpheresTheme.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(SpheresTheme.textTertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? SpheresTheme.accent.opacity(0.5) : SpheresTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CustomAnswerField: View {
    @Binding var text: String
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            TextField("Type your answer...", text: $text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(SpheresTheme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(SpheresTheme.accent.opacity(0.5), lineWidth: 1)
                )

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(GhostButtonStyle())

                Button("Submit", action: onSubmit)
                    .buttonStyle(SmallAccentButtonStyle())
                    .disabled(text.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SpheresTheme.surface)
        )
    }
}

struct OtherOptionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "pencil")
                    .foregroundColor(SpheresTheme.textSecondary)
                Text("Other (write your own)")
                    .font(.body)
                    .foregroundColor(SpheresTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SpheresTheme.border, style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Results View

struct OrientationResultsView: View {
    let profile: LifeOrientationProfile
    let scores: [LifeArea: Double]
    let prioritizedAreas: [LifeArea]
    let onContinue: () -> Void
    let onRetake: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                // Header with type
                VStack(spacing: 12) {
                    Image(systemName: profile.primaryType.icon)
                        .font(.system(size: 44))
                        .foregroundColor(SpheresTheme.accent)

                    Text("You're a \(profile.primaryType.rawValue)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(SpheresTheme.textPrimary)

                    Text(profile.primaryType.description)
                        .font(.subheadline)
                        .foregroundColor(SpheresTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)

                // Dimension visualization
                OrientationDimensionsView(profile: profile)
                    .padding(.horizontal, 50)

                // Life area priorities
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Life Priorities")
                        .font(.headline)
                        .foregroundColor(SpheresTheme.textPrimary)
                        .padding(.horizontal, 60)

                    VStack(spacing: 8) {
                        ForEach(Array(prioritizedAreas.enumerated()), id: \.element) { index, area in
                            LifeAreaResultCard(
                                area: area,
                                score: scores[area] ?? 0.2,
                                rank: index + 1
                            )
                        }
                    }
                    .padding(.horizontal, 60)
                }

                // Explanation
                VStack(spacing: 8) {
                    Text("Your personalized experience")
                        .font(.headline)
                        .foregroundColor(SpheresTheme.textPrimary)

                    Text("Spheres will adapt to your orientation — prioritizing what matters to you, speaking your language, and surfacing insights that fit how you think.")
                        .font(.caption)
                        .foregroundColor(SpheresTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SpheresTheme.surface)
                )
                .padding(.horizontal, 60)

                // Actions
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(SpheresTheme.accent)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button(action: onRetake) {
                        Text("Retake Quiz")
                            .font(.subheadline)
                            .foregroundColor(SpheresTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 30)
            }
        }
    }
}

struct OrientationDimensionsView: View {
    let profile: LifeOrientationProfile

    var body: some View {
        VStack(spacing: 16) {
            DimensionBar(
                leftLabel: "Solitude",
                rightLabel: "Community",
                leftIcon: "person.fill",
                rightIcon: "person.3.fill",
                value: profile.renewalSource
            )

            DimensionBar(
                leftLabel: "Contemplation",
                rightLabel: "Action",
                leftIcon: "brain.head.profile",
                rightIcon: "figure.run",
                value: profile.expressionMode
            )

            DimensionBar(
                leftLabel: "Inner Circle",
                rightLabel: "Wider Impact",
                leftIcon: "heart.fill",
                rightIcon: "globe.americas.fill",
                value: profile.careFocus
            )

            DimensionBar(
                leftLabel: "Present",
                rightLabel: "Future",
                leftIcon: "clock.fill",
                rightIcon: "star.fill",
                value: profile.timeHorizon
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SpheresTheme.surface)
        )
    }
}

struct DimensionBar: View {
    let leftLabel: String
    let rightLabel: String
    let leftIcon: String
    let rightIcon: String
    let value: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: leftIcon)
                        .font(.caption2)
                    Text(leftLabel)
                        .font(.caption)
                }
                .foregroundColor(value < 0.5 ? SpheresTheme.accent : SpheresTheme.textTertiary)

                Spacer()

                HStack(spacing: 4) {
                    Text(rightLabel)
                        .font(.caption)
                    Image(systemName: rightIcon)
                        .font(.caption2)
                }
                .foregroundColor(value > 0.5 ? SpheresTheme.accent : SpheresTheme.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(SpheresTheme.surfaceElevated)
                        .frame(height: 6)

                    Circle()
                        .fill(SpheresTheme.accent)
                        .frame(width: 14, height: 14)
                        .offset(x: (geo.size.width - 14) * value)
                }
            }
            .frame(height: 14)
        }
    }
}

struct LifeAreaResultCard: View {
    let area: LifeArea
    let score: Double
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(area.color.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text("\(rank)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(area.color)
            }

            HStack(spacing: 6) {
                Image(systemName: area.icon)
                    .foregroundColor(area.color)
                    .font(.system(size: 13))
                Text(area.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
            }

            Spacer()

            if rank <= 3 {
                Text(rank == 1 ? "Top" : "High")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(area.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(area.color.opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SpheresTheme.surface)
        )
    }
}

// MARK: - Legacy Views (Redirect to new quiz)

struct PriorityQuizView: View {
    @Binding var isPresented: Bool
    var onComplete: ([LifeArea: Double], [LifeArea], [String]) -> Void

    var body: some View {
        OrientationQuizView(isPresented: $isPresented) { _, scores, areas, custom in
            onComplete(scores, areas, custom)
        }
    }
}

struct ValuesQuizView: View {
    @Binding var isPresented: Bool
    var onComplete: ([SchwartzValue: Double], [SchwartzValue]) -> Void

    var body: some View {
        OrientationQuizView(isPresented: $isPresented) { profile, _, areas, _ in
            let schwartzScores = convertToSchwartzScores(areas)
            let topValues = Array(schwartzScores.sorted { $0.value > $1.value }.prefix(5).map { $0.key })
            onComplete(schwartzScores, topValues)
        }
    }

    private func convertToSchwartzScores(_ areas: [LifeArea]) -> [SchwartzValue: Double] {
        var scores: [SchwartzValue: Double] = [:]
        for value in SchwartzValue.allCases { scores[value] = 0.3 }

        for (index, area) in areas.enumerated() {
            let weight = 1.0 - (Double(index) * 0.1)
            switch area {
            case .faith:
                scores[.tradition, default: 0] += weight
                scores[.benevolence, default: 0] += weight * 0.5
            case .family:
                scores[.benevolence, default: 0] += weight
                scores[.security, default: 0] += weight * 0.5
            case .health:
                scores[.security, default: 0] += weight
            case .work:
                scores[.achievement, default: 0] += weight
            case .finances:
                scores[.security, default: 0] += weight
                scores[.power, default: 0] += weight * 0.5
            case .community:
                scores[.universalism, default: 0] += weight
            case .growth:
                scores[.selfDirection, default: 0] += weight
            }
        }

        let max = scores.values.max() ?? 1.0
        for value in SchwartzValue.allCases {
            scores[value] = (scores[value] ?? 0) / max
        }
        return scores
    }
}

// MARK: - Legacy UI Components

/// Legacy progress bar for ValuesQuizEngine
struct ValuesProgressBar: View {
    let progress: Double
    let totalSteps: Int

    var body: some View {
        OrientationProgressBar(progress: progress, totalSteps: totalSteps)
    }
}

/// Legacy question view for ValuesQuizEngine
struct ValuesQuestionView: View {
    let question: ValuesQuestion
    let questionNumber: Int
    let totalQuestions: Int
    let onSelect: (ValuesOption) -> Void
    let onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Question \(questionNumber) of \(totalQuestions)")
                .font(.caption)
                .foregroundColor(SpheresTheme.textTertiary)

            Text(question.scenario)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(SpheresTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(question.options) { option in
                        Button(action: { onSelect(option) }) {
                            HStack {
                                Text(option.text)
                                    .font(.body)
                                    .foregroundColor(SpheresTheme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(SpheresTheme.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(SpheresTheme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 60)
            }

            Spacer()

            if let onBack = onBack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundColor(SpheresTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
            }
        }
    }
}

/// Legacy result card for Schwartz values
struct ValueResultCard: View {
    let value: SchwartzValue
    let score: Double
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SpheresTheme.accent.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text("\(rank)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(SpheresTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text(value.description)
                    .font(.caption)
                    .foregroundColor(SpheresTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if rank <= 3 {
                Text(rank == 1 ? "Top" : "High")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(SpheresTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(SpheresTheme.accent.opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SpheresTheme.surface)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    OrientationQuizView(isPresented: .constant(true)) { profile, scores, areas, custom in
        print("Profile: \(profile)")
        print("Priorities: \(areas)")
    }
    .frame(width: 600, height: 700)
}
#endif
