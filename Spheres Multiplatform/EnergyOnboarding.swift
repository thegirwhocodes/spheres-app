//
//  EnergyOnboarding.swift
//  Spheres - Smart Life Manager
//
//  Startup-style energy profiling onboarding
//  Lets users draw their perceived energy curve and discover their chronotype
//

import SwiftUI
import Charts

// MARK: - Energy Profiling Sheet
struct EnergyProfilingSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var energyService = EnergyIntelligenceService.shared
    @State private var currentStep: EnergyStep = .intro
    @State private var drawnPoints: [CGPoint] = []
    @State private var chronotypeAnswer: Chronotype?
    @State private var exercisePreference: ExerciseTimePreference = .evening
    @State private var isAnalyzing = false
    @State private var analysisResult: CalendarAnalysisResult?
    @State private var workStartHour: Int = 8
    @State private var workEndHour: Int = 18

    enum EnergyStep: Int, CaseIterable {
        case intro = 0
        case chronotype = 1
        case drawEnergy = 2
        case preferences = 3
        case calendarAnalysis = 4
        case results = 5

        var title: String {
            switch self {
            case .intro: return "Understand Your Energy"
            case .chronotype: return "What's Your Chronotype?"
            case .drawEnergy: return "Draw Your Energy"
            case .preferences: return "Your Preferences"
            case .calendarAnalysis: return "Learning From Your Calendar"
            case .results: return "Your Energy Profile"
            }
        }
    }

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    SpheresTheme.background,
                    SpheresTheme.accent.opacity(0.1),
                    SpheresTheme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                EnergyProgressIndicator(currentStep: currentStep.rawValue, totalSteps: EnergyStep.allCases.count)
                    .padding(.top, 24)
                    .padding(.horizontal, 40)

                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        switch currentStep {
                        case .intro:
                            IntroStepView()
                        case .chronotype:
                            ChronotypeStepView(selectedChronotype: $chronotypeAnswer)
                        case .drawEnergy:
                            DrawEnergyStepView(drawnPoints: $drawnPoints)
                        case .preferences:
                            PreferencesStepView(
                                exercisePreference: $exercisePreference,
                                workStartHour: $workStartHour,
                                workEndHour: $workEndHour
                            )
                        case .calendarAnalysis:
                            CalendarAnalysisStepView(
                                isAnalyzing: $isAnalyzing,
                                progress: energyService.analysisProgress,
                                result: analysisResult
                            )
                        case .results:
                            ResultsStepView(
                                drawnPoints: drawnPoints,
                                chronotype: chronotypeAnswer ?? .thirdBird,
                                analysisResult: analysisResult
                            )
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 32)
                }

                // Navigation
                HStack(spacing: 16) {
                    if currentStep != .intro {
                        Button(action: previousStep) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(SpheresTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if currentStep == .calendarAnalysis && !isAnalyzing && analysisResult == nil {
                        Button(action: skipCalendarAnalysis) {
                            Text("Skip")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(SpheresTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 12)
                    }

                    Button(action: nextStep) {
                        HStack(spacing: 8) {
                            Text(nextButtonText)
                            if currentStep != .results {
                                Image(systemName: "arrow.right")
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    canProceed
                                        ? LinearGradient(colors: [SpheresTheme.accent, SpheresTheme.accent.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canProceed || isAnalyzing)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
        }
        .frame(width: 700, height: 650)
    }

    private var nextButtonText: String {
        switch currentStep {
        case .intro: return "Let's Begin"
        case .calendarAnalysis:
            if isAnalyzing { return "Analyzing..." }
            if analysisResult == nil { return "Analyze Calendar" }
            return "Continue"
        case .results: return "Save & Start Scheduling"
        default: return "Continue"
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case .chronotype: return chronotypeAnswer != nil
        case .drawEnergy: return drawnPoints.count >= 5
        case .calendarAnalysis: return !isAnalyzing
        default: return true
        }
    }

    private func nextStep() {
        if currentStep == .calendarAnalysis && analysisResult == nil {
            startCalendarAnalysis()
            return
        }

        if currentStep == .results {
            saveAndFinish()
            return
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            if let next = EnergyStep(rawValue: currentStep.rawValue + 1) {
                currentStep = next
            }
        }
    }

    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let prev = EnergyStep(rawValue: currentStep.rawValue - 1) {
                currentStep = prev
            }
        }
    }

    private func skipCalendarAnalysis() {
        withAnimation {
            currentStep = .results
        }
    }

    private func startCalendarAnalysis() {
        isAnalyzing = true
        Task {
            let result = await energyService.analyzeCalendarHistory(years: 2)
            await MainActor.run {
                analysisResult = result
                isAnalyzing = false
                if result.error == nil {
                    withAnimation {
                        currentStep = .results
                    }
                }
            }
        }
    }

    private func saveAndFinish() {
        // Build the energy profile
        var hourlyLevels: [Int: Double] = [:]

        // Start with chronotype defaults
        let chronotype = chronotypeAnswer ?? .thirdBird
        let baseProfile = EnergyProfile.default

        // Apply chronotype adjustments
        for hour in 0...23 {
            var level = baseProfile.hourlyEnergyLevels[hour] ?? 0.5

            // Adjust based on chronotype
            switch chronotype {
            case .morningLark:
                if hour < 12 { level = min(1.0, level * 1.2) }
                if hour > 14 { level = max(0.1, level * 0.8) }
            case .nightOwl:
                if hour < 12 { level = max(0.1, level * 0.7) }
                if hour > 16 { level = min(1.0, level * 1.3) }
            case .thirdBird:
                break // Use default
            }

            hourlyLevels[hour] = level
        }

        // Convert drawn points to hourly levels if available
        var userDrawnCurve: [CGPoint]? = nil
        if drawnPoints.count >= 5 {
            userDrawnCurve = drawnPoints
            // Also apply to hourly levels
            for hour in 0...23 {
                let normalizedX = Double(hour) / 24.0
                if let closest = drawnPoints.min(by: { abs($0.x - normalizedX) < abs($1.x - normalizedX) }) {
                    hourlyLevels[hour] = Double(closest.y)
                }
            }
        }

        // Apply calendar-derived patterns if available
        var calendarPattern: [Int: Double]? = nil
        if let result = analysisResult {
            calendarPattern = [:]
            for pattern in result.patterns where pattern.type == .productivePeak {
                if let hour = pattern.hour {
                    calendarPattern?[hour] = 0.9
                }
            }
        }

        let profile = EnergyProfile(
            chronotype: chronotype,
            hourlyEnergyLevels: hourlyLevels,
            userDrawnCurve: userDrawnCurve,
            calendarDerivedPattern: calendarPattern,
            preferredWorkHours: workStartHour...workEndHour,
            preferredExerciseTime: exercisePreference,
            lastUpdated: Date()
        )

        energyService.saveProfile(profile)
        isPresented = false
    }
}

// MARK: - Progress Indicator
struct EnergyProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? SpheresTheme.accent : SpheresTheme.surface)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }
}

// MARK: - Step Views

struct IntroStepView: View {
    var body: some View {
        VStack(spacing: 28) {
            // Animated energy wave
            ZStack {
                Circle()
                    .fill(SpheresTheme.accent.opacity(0.1))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(SpheresTheme.accent.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 50))
                    .foregroundColor(SpheresTheme.accent)
            }
            .padding(.top, 20)

            VStack(spacing: 16) {
                Text("Your Energy, Optimized")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Spheres uses neuroscience research to schedule your tasks at the perfect time — when your brain is primed for that type of work.")
                    .font(.system(size: 16))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Research highlights
            VStack(spacing: 12) {
                ResearchHighlight(
                    icon: "brain",
                    title: "Circadian Science",
                    description: "Peak focus varies by 20% based on time of day"
                )

                ResearchHighlight(
                    icon: "clock.fill",
                    title: "90-Minute Cycles",
                    description: "Your brain naturally cycles every 90-120 minutes"
                )

                ResearchHighlight(
                    icon: "person.fill",
                    title: "Personal Patterns",
                    description: "We'll learn your unique energy rhythm"
                )
            }
            .padding(.top, 8)
        }
    }
}

struct ResearchHighlight: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(SpheresTheme.accent)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(SpheresTheme.accent.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(SpheresTheme.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SpheresTheme.surface)
        )
    }
}

struct ChronotypeStepView: View {
    @Binding var selectedChronotype: Chronotype?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("When do you feel most alive?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("Your chronotype is your natural sleep-wake pattern. It determines when you're sharpest and when you need rest.")
                    .font(.system(size: 15))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                ForEach(Chronotype.allCases, id: \.self) { type in
                    ChronotypeCard(
                        chronotype: type,
                        isSelected: selectedChronotype == type,
                        onSelect: { selectedChronotype = type }
                    )
                }
            }

            // Info callout
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                Text("65% of people are \"Third Birds\" — not extreme morning or night types.")
                    .font(.system(size: 12))
                    .foregroundColor(SpheresTheme.textSecondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
            )
        }
    }
}

struct ChronotypeCard: View {
    let chronotype: Chronotype
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(chronotypeColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: chronotypeIcon)
                        .font(.system(size: 22))
                        .foregroundColor(chronotypeColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(chronotype.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)

                        Text(populationText)
                            .font(.system(size: 11))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(SpheresTheme.surface)
                            )
                    }

                    Text(chronotype.description)
                        .font(.system(size: 13))
                        .foregroundColor(SpheresTheme.textSecondary)
                        .lineLimit(2)

                    Text("Peak: \(peakTimeText)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(chronotypeColor)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? chronotypeColor : SpheresTheme.border, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(chronotypeColor)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(SpheresTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? chronotypeColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var chronotypeIcon: String {
        switch chronotype {
        case .morningLark: return "sunrise.fill"
        case .thirdBird: return "sun.max.fill"
        case .nightOwl: return "moon.stars.fill"
        }
    }

    private var chronotypeColor: Color {
        switch chronotype {
        case .morningLark: return .orange
        case .thirdBird: return .yellow
        case .nightOwl: return .indigo
        }
    }

    private var populationText: String {
        switch chronotype {
        case .morningLark: return "15%"
        case .thirdBird: return "65%"
        case .nightOwl: return "20%"
        }
    }

    private var peakTimeText: String {
        switch chronotype {
        case .morningLark: return "8-11 AM"
        case .thirdBird: return "10 AM-12 PM"
        case .nightOwl: return "4-9 PM"
        }
    }
}

// MARK: - Draw Energy View
struct DrawEnergyStepView: View {
    @Binding var drawnPoints: [CGPoint]
    @State private var isDrawing = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Draw Your Energy Curve")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("Trace how your energy feels throughout the day. Start from the left (morning) and draw to the right (night).")
                    .font(.system(size: 15))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Drawing canvas
            EnergyDrawingCanvas(points: $drawnPoints, isDrawing: $isDrawing)
                .frame(height: 220)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(SpheresTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isDrawing ? SpheresTheme.accent : SpheresTheme.border, lineWidth: 2)
                        )
                )

            // Time labels
            HStack {
                Text("6 AM")
                Spacer()
                Text("12 PM")
                Spacer()
                Text("6 PM")
                Spacer()
                Text("12 AM")
            }
            .font(.system(size: 11))
            .foregroundColor(SpheresTheme.textTertiary)
            .padding(.horizontal, 8)

            // Clear button
            if !drawnPoints.isEmpty {
                Button(action: { drawnPoints.removeAll() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Clear & Redraw")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Hints
            VStack(alignment: .leading, spacing: 8) {
                HintRow(text: "Draw higher for times when you feel most energetic")
                HintRow(text: "Draw lower for energy dips (like after lunch)")
                HintRow(text: "Don't worry about being exact — this helps us learn")
            }
            .padding(.top, 8)
        }
    }
}

struct HintRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow)

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.textSecondary)
        }
    }
}

struct EnergyDrawingCanvas: View {
    @Binding var points: [CGPoint]
    @Binding var isDrawing: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid lines
                VStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        Rectangle()
                            .fill(SpheresTheme.border.opacity(0.3))
                            .frame(height: 1)
                        if i < 4 {
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 20)

                // Y-axis labels
                HStack {
                    VStack {
                        Text("High")
                            .font(.system(size: 9))
                            .foregroundColor(SpheresTheme.textTertiary)
                        Spacer()
                        Text("Low")
                            .font(.system(size: 9))
                            .foregroundColor(SpheresTheme.textTertiary)
                    }
                    .frame(width: 30)
                    .padding(.vertical, 16)

                    Spacer()
                }

                // Drawn path
                if !points.isEmpty {
                    Path { path in
                        let scaledPoints = points.map { point in
                            CGPoint(
                                x: point.x * geometry.size.width,
                                y: (1 - point.y) * geometry.size.height
                            )
                        }

                        if let first = scaledPoints.first {
                            path.move(to: first)
                            for point in scaledPoints.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [SpheresTheme.accent, SpheresTheme.accent.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )

                    // Area fill
                    Path { path in
                        let scaledPoints = points.map { point in
                            CGPoint(
                                x: point.x * geometry.size.width,
                                y: (1 - point.y) * geometry.size.height
                            )
                        }

                        if let first = scaledPoints.first {
                            path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                            path.addLine(to: first)
                            for point in scaledPoints.dropFirst() {
                                path.addLine(to: point)
                            }
                            if let last = scaledPoints.last {
                                path.addLine(to: CGPoint(x: last.x, y: geometry.size.height))
                            }
                            path.closeSubpath()
                        }
                    }
                    .fill(
                        LinearGradient(
                            colors: [SpheresTheme.accent.opacity(0.3), SpheresTheme.accent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDrawing = true
                        let normalizedPoint = CGPoint(
                            x: max(0, min(1, value.location.x / geometry.size.width)),
                            y: max(0, min(1, 1 - value.location.y / geometry.size.height))
                        )

                        // Add point only if it's to the right of the last point
                        if let last = points.last {
                            if normalizedPoint.x > last.x {
                                points.append(normalizedPoint)
                            }
                        } else {
                            points.append(normalizedPoint)
                        }
                    }
                    .onEnded { _ in
                        isDrawing = false
                    }
            )
        }
        .padding(16)
    }
}

// MARK: - Preferences Step
struct PreferencesStepView: View {
    @Binding var exercisePreference: ExerciseTimePreference
    @Binding var workStartHour: Int
    @Binding var workEndHour: Int

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Text("A Few Preferences")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("Help us personalize your schedule even more.")
                    .font(.system(size: 15))
                    .foregroundColor(SpheresTheme.textSecondary)
            }

            // Work hours
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Work Hours")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start")
                            .font(.system(size: 12))
                            .foregroundColor(SpheresTheme.textSecondary)

                        Picker("", selection: $workStartHour) {
                            ForEach(5...12, id: \.self) { hour in
                                Text("\(hour):00 AM").tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("End")
                            .font(.system(size: 12))
                            .foregroundColor(SpheresTheme.textSecondary)

                        Picker("", selection: $workEndHour) {
                            ForEach(14...22, id: \.self) { hour in
                                Text("\(hour > 12 ? hour - 12 : hour):00 \(hour >= 12 ? "PM" : "AM")").tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }

                    Spacer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SpheresTheme.surface)
            )

            // Exercise preference
            VStack(alignment: .leading, spacing: 12) {
                Text("When Do You Prefer to Exercise?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                VStack(spacing: 10) {
                    ForEach(ExerciseTimePreference.allCases, id: \.self) { pref in
                        ExercisePreferenceCard(
                            preference: pref,
                            isSelected: exercisePreference == pref,
                            onSelect: { exercisePreference = pref }
                        )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SpheresTheme.surface)
            )
        }
    }
}

struct ExercisePreferenceCard: View {
    let preference: ExerciseTimePreference
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: preferenceIcon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .green : SpheresTheme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preference.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SpheresTheme.textPrimary)

                    Text(preference.benefits)
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.green.opacity(0.1) : SpheresTheme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.green.opacity(0.5) : SpheresTheme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var preferenceIcon: String {
        switch preference {
        case .morning: return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .evening: return "sunset.fill"
        }
    }
}

// MARK: - Calendar Analysis Step
struct CalendarAnalysisStepView: View {
    @Binding var isAnalyzing: Bool
    let progress: Double
    let result: CalendarAnalysisResult?

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Text("Learn From Your History")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("We can analyze your past 2 years of calendar events to discover your actual productivity patterns.")
                    .font(.system(size: 15))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if isAnalyzing {
                // Progress view
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(SpheresTheme.surface, lineWidth: 8)
                            .frame(width: 120, height: 120)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(SpheresTheme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: progress)

                        VStack(spacing: 4) {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(SpheresTheme.textPrimary)

                            Text("Analyzing")
                                .font(.system(size: 12))
                                .foregroundColor(SpheresTheme.textSecondary)
                        }
                    }

                    Text(analysisStageText)
                        .font(.system(size: 13))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
                .padding(.vertical, 40)
            } else if let result = result {
                // Results preview
                if let error = result.error {
                    ErrorView(message: error)
                } else {
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Analysis Complete")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.green)
                        }

                        Text("Found \(result.patterns.count) patterns and \(result.insights.count) insights")
                            .font(.system(size: 14))
                            .foregroundColor(SpheresTheme.textSecondary)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                }
            } else {
                // Not yet started
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 60))
                        .foregroundColor(SpheresTheme.accent.opacity(0.5))

                    VStack(spacing: 8) {
                        Text("What We'll Look For")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)

                        VStack(alignment: .leading, spacing: 6) {
                            AnalysisFeature(text: "When you schedule deep work")
                            AnalysisFeature(text: "Your meeting patterns")
                            AnalysisFeature(text: "Exercise timing preferences")
                            AnalysisFeature(text: "Completion time patterns")
                        }
                    }
                }
                .padding(.vertical, 20)
            }

            // Privacy note
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)

                Text("Analysis happens on your device. No calendar data is sent anywhere.")
                    .font(.system(size: 12))
                    .foregroundColor(SpheresTheme.textSecondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.1))
            )
        }
    }

    private var analysisStageText: String {
        if progress < 0.3 {
            return "Loading calendar events..."
        } else if progress < 0.7 {
            return "Categorizing activities..."
        } else if progress < 0.9 {
            return "Detecting patterns..."
        } else {
            return "Generating insights..."
        }
    }
}

struct AnalysisFeature: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(SpheresTheme.accent)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(SpheresTheme.textSecondary)
        }
    }
}

struct ErrorView: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Couldn't analyze calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(SpheresTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

// MARK: - Results Step
struct ResultsStepView: View {
    let drawnPoints: [CGPoint]
    let chronotype: Chronotype
    let analysisResult: CalendarAnalysisResult?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(SpheresTheme.accent)

                Text("Your Energy Profile")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text("We've created a personalized energy model just for you.")
                    .font(.system(size: 15))
                    .foregroundColor(SpheresTheme.textSecondary)
            }

            // Chronotype badge
            HStack(spacing: 10) {
                Image(systemName: chronotypeIcon)
                    .font(.system(size: 18))
                    .foregroundColor(chronotypeColor)

                Text(chronotype.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Spacer()

                Text("Peak: \(peakTimeText)")
                    .font(.system(size: 13))
                    .foregroundColor(chronotypeColor)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(chronotypeColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(chronotypeColor.opacity(0.3), lineWidth: 1)
                    )
            )

            // Energy curve preview
            if !drawnPoints.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Energy Curve")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SpheresTheme.textSecondary)

                    EnergyPreviewChart(points: drawnPoints)
                        .frame(height: 100)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SpheresTheme.surface)
                )
            }

            // Insights from calendar
            if let result = analysisResult, !result.insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Insights From Your Calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SpheresTheme.textSecondary)

                    ForEach(result.insights.prefix(3)) { insight in
                        InsightCard(insight: insight)
                    }
                }
            }

            // What happens next
            VStack(alignment: .leading, spacing: 8) {
                Text("What's Next")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SpheresTheme.textSecondary)

                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(SpheresTheme.accent)
                    Text("Spheres will now suggest optimal times for your tasks")
                        .font(.system(size: 13))
                        .foregroundColor(SpheresTheme.textPrimary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(SpheresTheme.accent)
                    Text("Your profile will improve as we learn from your behavior")
                        .font(.system(size: 13))
                        .foregroundColor(SpheresTheme.textPrimary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SpheresTheme.surface)
            )
        }
    }

    private var chronotypeIcon: String {
        switch chronotype {
        case .morningLark: return "sunrise.fill"
        case .thirdBird: return "sun.max.fill"
        case .nightOwl: return "moon.stars.fill"
        }
    }

    private var chronotypeColor: Color {
        switch chronotype {
        case .morningLark: return .orange
        case .thirdBird: return .yellow
        case .nightOwl: return .indigo
        }
    }

    private var peakTimeText: String {
        switch chronotype {
        case .morningLark: return "8-11 AM"
        case .thirdBird: return "10 AM-12 PM"
        case .nightOwl: return "4-9 PM"
        }
    }
}

struct EnergyPreviewChart: View {
    let points: [CGPoint]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let scaledPoints = points.map { point in
                    CGPoint(
                        x: point.x * geometry.size.width,
                        y: (1 - point.y) * geometry.size.height
                    )
                }

                if let first = scaledPoints.first {
                    path.move(to: first)
                    for point in scaledPoints.dropFirst() {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(SpheresTheme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

struct InsightCard: View {
    let insight: EnergyInsight

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .font(.system(size: 16))
                .foregroundColor(priorityColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(priorityColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Text(insight.recommendation)
                    .font(.system(size: 12))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SpheresTheme.surface)
        )
    }

    private var priorityColor: Color {
        switch insight.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

// MARK: - Preview
#Preview {
    EnergyProfilingSheet(isPresented: .constant(true))
}
