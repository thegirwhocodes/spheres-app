//
//  SmartSetupService.swift
//  Spheres - Smart Life Manager
//
//  Orchestrates AI-powered onboarding: scans Mac ecosystem data sources,
//  sends summarized data to Claude Sonnet, and generates personalized spheres + tasks.
//

import SwiftUI
import SwiftData

// MARK: - Scan Phase

enum ScanPhase: Equatable {
    case idle
    case requestingPermissions
    case scanningSource(String)  // Source display name
    case scanningCalendar
    case aggregating
    case analyzingWithAI
    case complete
    case failed(String)

    static func == (lhs: ScanPhase, rhs: ScanPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.requestingPermissions, .requestingPermissions),
             (.scanningCalendar, .scanningCalendar), (.aggregating, .aggregating),
             (.analyzingWithAI, .analyzingWithAI), (.complete, .complete):
            return true
        case (.scanningSource(let a), .scanningSource(let b)):
            return a == b
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - AI Generated Setup

struct AIGeneratedSetup: Codable {
    var spheres: [GeneratedSphere]
    var insights: String
    var suggestedValues: [String]

    struct GeneratedSphere: Codable, Identifiable {
        let id: UUID
        var name: String
        var icon: String
        var description: String
        var color: ColorComponents
        var priorityRank: Int
        var tasks: [GeneratedTask]
        var isEnabled: Bool

        struct ColorComponents: Codable {
            let r: Double
            let g: Double
            let b: Double
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID() // Always generate fresh
            self.name = try container.decode(String.self, forKey: .name)
            self.icon = try container.decode(String.self, forKey: .icon)
            self.description = try container.decode(String.self, forKey: .description)
            self.color = try container.decode(ColorComponents.self, forKey: .color)
            self.priorityRank = try container.decode(Int.self, forKey: .priorityRank)

            // Decode tasks and assign IDs
            var rawTasks = try container.decode([GeneratedTask].self, forKey: .tasks)
            for i in rawTasks.indices {
                rawTasks[i] = GeneratedTask(
                    id: UUID(),
                    content: rawTasks[i].content,
                    importance: rawTasks[i].importance,
                    source: rawTasks[i].source,
                    estimatedMinutes: rawTasks[i].estimatedMinutes,
                    dueDate: rawTasks[i].dueDate,
                    isEnabled: true
                )
            }
            self.tasks = rawTasks
            self.isEnabled = true
        }

        // Manual init for fallback
        init(id: UUID = UUID(), name: String, icon: String, description: String, color: ColorComponents, priorityRank: Int, tasks: [GeneratedTask], isEnabled: Bool = true) {
            self.id = id
            self.name = name
            self.icon = icon
            self.description = description
            self.color = color
            self.priorityRank = priorityRank
            self.tasks = tasks
            self.isEnabled = isEnabled
        }
    }

    struct GeneratedTask: Codable, Identifiable {
        var id: UUID
        var content: String
        var importance: Int
        var source: String
        var estimatedMinutes: Int?
        var dueDate: Date?
        var isEnabled: Bool

        init(id: UUID = UUID(), content: String, importance: Int, source: String, estimatedMinutes: Int? = nil, dueDate: Date? = nil, isEnabled: Bool = true) {
            self.id = id
            self.content = content
            self.importance = importance
            self.source = source
            self.estimatedMinutes = estimatedMinutes
            self.dueDate = dueDate
            self.isEnabled = isEnabled
        }
    }
}

// MARK: - Smart Setup Service

@MainActor
class SmartSetupService: ObservableObject {
    static let shared = SmartSetupService()

    @Published var scanPhase: ScanPhase = .idle
    @Published var scanProgress: Double = 0.0
    @Published var currentSourceLabel: String = ""
    @Published var aiGeneratedSetup: AIGeneratedSetup?
    @Published var scanError: String?
    @Published var completedSources: [String] = []

    // Configuration
    @Published var enabledSources: Set<TaskSource> = [.reminders, .notes, .appleMail]
    @Published var calendarEnabled: Bool = true

    private let adapterManager = SourceAdapterManager.shared
    private let calendarService = CalendarService.shared
    private let aiService = AIService.shared

    private init() {}

    // MARK: - Full Scan Pipeline

    func performFullScan() async {
        scanPhase = .idle
        scanProgress = 0.0
        scanError = nil
        completedSources = []
        aiGeneratedSetup = nil

        // Count total steps for progress
        let sourceCount = enabledSources.count + (calendarEnabled ? 1 : 0)
        let totalSteps = Double(sourceCount + 2) // sources + aggregation + AI
        var currentStep = 0.0

        // Step 1: Scan each enabled source
        var allTasks: [ExtractedTask] = []
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())

        for source in enabledSources {
            guard let adapter = getAdapter(for: source) else { continue }

            scanPhase = .scanningSource(source.rawValue)
            currentSourceLabel = "Scanning \(source.rawValue)..."

            // Check and request permissions
            let hasPermission = await adapter.checkPermissions()
            if !hasPermission {
                let granted = await adapter.requestPermissions()
                if !granted {
                    print("DEBUG: SmartSetup skipping \(source.rawValue) - permission denied")
                    currentStep += 1
                    scanProgress = currentStep / totalSteps
                    continue
                }
            }

            // Enable the permission in UserDefaults so SourceAdapterManager knows
            enablePermission(for: source)

            do {
                let tasks = try await adapter.extractTasks(since: thirtyDaysAgo, limit: 100)
                allTasks.append(contentsOf: tasks)
                completedSources.append(source.rawValue)
                print("DEBUG: SmartSetup extracted \(tasks.count) tasks from \(source.rawValue)")
            } catch {
                print("DEBUG: SmartSetup error scanning \(source.rawValue): \(error)")
            }

            currentStep += 1
            scanProgress = currentStep / totalSteps
        }

        // Step 2: Scan calendar
        var calendarSummary = ""
        if calendarEnabled {
            scanPhase = .scanningCalendar
            currentSourceLabel = "Scanning Calendar..."

            if calendarService.hasAccess {
                calendarSummary = calendarService.summarizeRecentActivity(days: 30)
                completedSources.append("Calendar")
            } else {
                let granted = await calendarService.requestAccess()
                if granted {
                    calendarSummary = calendarService.summarizeRecentActivity(days: 30)
                    completedSources.append("Calendar")
                }
            }

            currentStep += 1
            scanProgress = currentStep / totalSteps
        }

        // Step 3: Aggregate
        scanPhase = .aggregating
        currentSourceLabel = "Preparing data..."

        let payload = buildAIPayload(tasks: allTasks, calendarSummary: calendarSummary)
        currentStep += 1
        scanProgress = currentStep / totalSteps

        // Check if we have enough data
        if allTasks.isEmpty && calendarSummary.isEmpty {
            scanPhase = .failed("notEnoughData")
            scanError = "We didn't find enough data to generate personalized spheres. You can set up spheres manually."
            return
        }

        // Step 4: Send to AI
        scanPhase = .analyzingWithAI
        currentSourceLabel = "AI is analyzing your life..."

        do {
            let response = try await aiService.sendStructuredMessage(
                payload,
                systemPrompt: smartSetupSystemPrompt,
                maxTokens: 3000,
                model: "claude-sonnet-4-20250514"
            )

            // Parse JSON response
            if let setup = parseAIResponse(response) {
                aiGeneratedSetup = setup
                scanPhase = .complete
                scanProgress = 1.0
                print("DEBUG: SmartSetup generated \(setup.spheres.count) spheres with \(setup.spheres.flatMap { $0.tasks }.count) tasks")
            } else {
                // Retry once with a simpler prompt
                print("DEBUG: SmartSetup first parse failed, retrying...")
                let retryResponse = try await aiService.sendStructuredMessage(
                    payload,
                    systemPrompt: smartSetupSystemPromptSimple,
                    maxTokens: 3000,
                    model: "claude-sonnet-4-20250514"
                )

                if let retrySetup = parseAIResponse(retryResponse) {
                    aiGeneratedSetup = retrySetup
                    scanPhase = .complete
                    scanProgress = 1.0
                } else {
                    // Fall back to keyword-based grouping
                    aiGeneratedSetup = buildFallbackSetup(from: allTasks)
                    scanPhase = .complete
                    scanProgress = 1.0
                }
            }
        } catch {
            print("DEBUG: SmartSetup AI error: \(error)")
            // Fall back to keyword-based grouping
            aiGeneratedSetup = buildFallbackSetup(from: allTasks)
            if aiGeneratedSetup != nil {
                scanPhase = .complete
                scanProgress = 1.0
            } else {
                scanPhase = .failed(error.localizedDescription)
                scanError = "AI analysis failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Materialize (Create actual spheres + loops)

    func materialize(_ setup: AIGeneratedSetup, modelContext: ModelContext) {
        for sphere in setup.spheres where sphere.isEnabled {
            let sphereModel = SphereModel(
                name: sphere.name,
                icon: sphere.icon,
                color: Color(red: sphere.color.r, green: sphere.color.g, blue: sphere.color.b),
                description: sphere.description,
                priorityRank: sphere.priorityRank
            )
            modelContext.insert(sphereModel)

            for task in sphere.tasks where task.isEnabled {
                let loop = OpenLoopModel(
                    content: task.content,
                    sphere: sphereModel,
                    importance: task.importance,
                    progress: 0.0,
                    estimatedMinutes: task.estimatedMinutes,
                    dueDate: task.dueDate
                )
                modelContext.insert(loop)
            }
        }

        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: "hasUsedSmartSetup")
            print("DEBUG: SmartSetup materialized \(setup.spheres.filter { $0.isEnabled }.count) spheres")
        } catch {
            print("DEBUG: SmartSetup materialization error: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func getAdapter(for source: TaskSource) -> (any SourceAdapter)? {
        switch source {
        case .reminders: return RemindersAdapter()
        case .appleMail: return AppleMailAdapter()
        case .notes: return NotesAdapter()
        case .voiceMemos: return VoiceMemosAdapter()
        case .iMessage: return IMessageAdapter()
        default: return nil
        }
    }

    private func enablePermission(for source: TaskSource) {
        switch source {
        case .reminders: UserDefaults.standard.set(true, forKey: "permission.reminders")
        case .appleMail: UserDefaults.standard.set(true, forKey: "permission.gmail")
        case .notes: UserDefaults.standard.set(true, forKey: "permission.notes")
        case .voiceMemos: UserDefaults.standard.set(true, forKey: "permission.voiceMemos")
        case .iMessage: UserDefaults.standard.set(true, forKey: "permission.imessage")
        case .calendar: UserDefaults.standard.set(true, forKey: "permission.calendar")
        default: break
        }
    }

    // MARK: - AI Payload Construction

    private func buildAIPayload(tasks: [ExtractedTask], calendarSummary: String) -> String {
        var sections: [String] = []

        // Calendar summary
        if !calendarSummary.isEmpty {
            sections.append("## Calendar Activity (Last 30 Days)\n\(calendarSummary)")
        }

        // Group tasks by source
        let tasksBySource = Dictionary(grouping: tasks, by: { $0.source })

        for (source, sourceTasks) in tasksBySource.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let limited = sourceTasks.prefix(50)
            let taskList = limited.map { task in
                var line = "- \(task.content)"
                if let context = task.context, !context.isEmpty {
                    line += " (from: \(context))"
                }
                return line
            }.joined(separator: "\n")

            sections.append("## \(source.rawValue) (\(sourceTasks.count) items)\n\(taskList)")
        }

        return """
        Here is my digital footprint from the last 30 days:

        \(sections.joined(separator: "\n\n"))

        Please analyze this data and create my personalized spheres.
        """
    }

    // MARK: - AI Prompts

    private var smartSetupSystemPrompt: String {
        """
        You are an AI assistant for the Spheres productivity app. Your task is to analyze a user's digital footprint and create personalized life management categories called "spheres" with tasks.

        Rules:
        1. Create 4-8 spheres based on ACTUAL patterns in the data (not generic defaults like "Health" or "Work")
        2. Name spheres specifically to this person's life (e.g., "PhD Research" not "Education", "Marathon Training" not "Health", "Side Hustle" not "Career")
        3. Each sphere needs: name, SF Symbol icon name, RGB color (0.0-1.0 range), description, priority rank (1=highest)
        4. Categorize every extracted task into exactly one sphere
        5. Set task importance: 1=urgent/critical, 2=high, 3=medium, 4=low, 5=someday
        6. If a task has obvious time sensitivity, set estimatedMinutes
        7. Respond ONLY with valid JSON matching the schema below — no markdown, no explanation outside JSON

        Valid SF Symbol names (pick from these):
        heart.fill, briefcase.fill, book.fill, figure.2.and.child.holdinghands, paintbrush.fill, sparkles, dollarsign.circle.fill, person.3.fill, arrow.up.circle.fill, house.fill, airplane, gamecontroller.fill, globe.americas.fill, leaf.fill, music.note, graduationcap.fill, cross.fill, dumbbell.fill, fork.knife, bed.double.fill, laptopcomputer, wrench.fill, camera.fill, chart.line.uptrend.xyaxis, brain.head.profile, stethoscope, car.fill, cart.fill, phone.fill, envelope.fill, doc.text.fill, calendar, gift.fill, star.fill, bolt.fill, flame.fill

        Good color choices for a dark UI (avoid very dark colors):
        Purple: {"r": 0.55, "g": 0.36, "b": 0.96}
        Blue: {"r": 0.2, "g": 0.5, "b": 1.0}
        Green: {"r": 0.2, "g": 0.78, "b": 0.35}
        Pink: {"r": 1.0, "g": 0.4, "b": 0.6}
        Orange: {"r": 1.0, "g": 0.6, "b": 0.2}
        Teal: {"r": 0.3, "g": 0.85, "b": 0.9}
        Red: {"r": 0.9, "g": 0.3, "b": 0.3}
        Gold: {"r": 0.95, "g": 0.8, "b": 0.2}

        JSON Schema:
        {
          "spheres": [
            {
              "name": "string",
              "icon": "string",
              "description": "string",
              "color": {"r": 0.0, "g": 0.0, "b": 0.0},
              "priorityRank": 1,
              "tasks": [
                {
                  "content": "string",
                  "importance": 2,
                  "source": "string",
                  "estimatedMinutes": null
                }
              ]
            }
          ],
          "insights": "2-3 sentences about what you observed in their data",
          "suggestedValues": ["achievement", "benevolence"]
        }
        """
    }

    private var smartSetupSystemPromptSimple: String {
        """
        Analyze the user's data and create 4-6 life categories ("spheres") with tasks. Respond ONLY with valid JSON.

        Format:
        {"spheres":[{"name":"string","icon":"star.fill","description":"string","color":{"r":0.5,"g":0.5,"b":0.5},"priorityRank":1,"tasks":[{"content":"string","importance":2,"source":"string"}]}],"insights":"string","suggestedValues":["string"]}

        Icons must be valid SF Symbols. Name spheres specifically to the person's actual life activities.
        """
    }

    // MARK: - Response Parsing

    private func parseAIResponse(_ response: String) -> AIGeneratedSetup? {
        // Try to extract JSON from response (AI might wrap in markdown code blocks)
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code block if present
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8) else {
            print("DEBUG: SmartSetup could not convert response to data")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let setup = try decoder.decode(AIGeneratedSetup.self, from: data)

            // Validate: must have at least 1 sphere
            guard !setup.spheres.isEmpty else {
                print("DEBUG: SmartSetup parsed 0 spheres")
                return nil
            }

            return setup
        } catch {
            print("DEBUG: SmartSetup JSON parse error: \(error)")
            return nil
        }
    }

    // MARK: - Fallback: Keyword-based Grouping

    private func buildFallbackSetup(from tasks: [ExtractedTask]) -> AIGeneratedSetup? {
        guard !tasks.isEmpty else { return nil }

        // Group tasks by suggestedSphere or keyword patterns
        var groups: [String: [ExtractedTask]] = [:]

        for task in tasks {
            let category = task.suggestedSphere ?? categorizeByKeywords(task.content)
            groups[category, default: []].append(task)
        }

        // Convert to GeneratedSpheres
        let defaultColors: [AIGeneratedSetup.GeneratedSphere.ColorComponents] = [
            .init(r: 0.55, g: 0.36, b: 0.96),
            .init(r: 0.2, g: 0.5, b: 1.0),
            .init(r: 0.2, g: 0.78, b: 0.35),
            .init(r: 1.0, g: 0.4, b: 0.6),
            .init(r: 1.0, g: 0.6, b: 0.2),
            .init(r: 0.3, g: 0.85, b: 0.9),
            .init(r: 0.9, g: 0.3, b: 0.3),
            .init(r: 0.95, g: 0.8, b: 0.2),
        ]

        var spheres: [AIGeneratedSetup.GeneratedSphere] = []
        let sortedGroups = groups.sorted { $0.value.count > $1.value.count }

        for (index, (category, groupTasks)) in sortedGroups.prefix(8).enumerated() {
            let generatedTasks = groupTasks.map { task in
                AIGeneratedSetup.GeneratedTask(
                    content: task.content,
                    importance: task.suggestedPriority ?? 3,
                    source: task.source.rawValue
                )
            }

            spheres.append(AIGeneratedSetup.GeneratedSphere(
                name: category,
                icon: "star.fill",
                description: "Tasks related to \(category.lowercased())",
                color: defaultColors[index % defaultColors.count],
                priorityRank: index + 1,
                tasks: generatedTasks
            ))
        }

        return AIGeneratedSetup(spheres: spheres, insights: "Organized based on task categories found in your data.", suggestedValues: [])
    }

    private func categorizeByKeywords(_ content: String) -> String {
        let lowered = content.lowercased()

        let categories: [(keywords: [String], name: String)] = [
            (["meeting", "email", "report", "project", "deadline", "client", "presentation", "office"], "Work"),
            (["gym", "workout", "run", "health", "doctor", "exercise", "sleep", "diet"], "Health"),
            (["mom", "dad", "family", "kids", "birthday", "dinner", "spouse", "partner"], "Family"),
            (["study", "course", "read", "learn", "book", "class", "homework", "research"], "Learning"),
            (["pay", "bill", "budget", "invest", "bank", "tax", "insurance", "save"], "Finances"),
            (["church", "pray", "faith", "spiritual", "worship", "bible", "devotional"], "Faith"),
            (["friend", "volunteer", "community", "social", "party", "event", "group"], "Community"),
            (["write", "design", "create", "art", "music", "photo", "video", "blog"], "Creative"),
        ]

        for (keywords, name) in categories {
            if keywords.contains(where: { lowered.contains($0) }) {
                return name
            }
        }

        return "General"
    }
}
