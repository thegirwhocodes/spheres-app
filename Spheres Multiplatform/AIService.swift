//
//  AIService.swift
//  Spheres - Smart Life Manager
//
//  AI integration service for Claude API
//

import SwiftUI
import SwiftData

// MARK: - AI Service
@MainActor
class AIService: ObservableObject {
    static let shared = AIService()

    @Published var isProcessing = false
    @Published var lastError: String?

    // API Configuration
    @AppStorage("claudeAPIKey") private var apiKey: String = ""
    private let baseURL = "https://api.anthropic.com/v1/messages"

    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }

    func setAPIKey(_ key: String) {
        apiKey = key
    }

    func getAPIKey() -> String {
        apiKey
    }

    // MARK: - Sphere Classification
    func classifyInboxItem(_ content: String, spheres: [SphereModel]) async -> SphereModel? {
        guard hasAPIKey else { return nil }

        let sphereList = spheres.map { "\($0.name): \($0.sphereDescription)" }.joined(separator: "\n")

        let prompt = """
        You are a helpful assistant that categorizes tasks into life spheres.

        Available spheres:
        \(sphereList)

        Task to categorize: "\(content)"

        Respond with ONLY the sphere name that best fits this task. Nothing else.
        """

        do {
            let response = try await sendMessage(prompt, maxTokens: 50)
            let suggestedName = response.trimmingCharacters(in: .whitespacesAndNewlines)
            return spheres.first { $0.name.lowercased() == suggestedName.lowercased() }
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Smart Resurfacing
    func getResurfacingSuggestions(loops: [OpenLoopModel], spheres: [SphereModel]) async -> [ResurfacingSuggestion] {
        guard hasAPIKey else { return generateLocalResurfacing(loops: loops) }

        let loopSummary = loops.prefix(20).map { loop in
            let sphere = loop.sphere?.name ?? "Unassigned"
            let days = Calendar.current.dateComponents([.day], from: loop.createdDate, to: Date()).day ?? 0
            return "- \(loop.content) [Sphere: \(sphere), Priority: \(loop.importance), Days old: \(days), Progress: \(Int(loop.progress * 100))%]"
        }.joined(separator: "\n")

        let prompt = """
        You are a productivity assistant analyzing open tasks (called "loops").

        Here are the user's open loops:
        \(loopSummary)

        Suggest 3 loops that should be resurfaced today, considering:
        1. High priority items that have been neglected
        2. Items close to completion that could provide quick wins
        3. Time-sensitive or urgent matters

        Respond in this exact format for each (one per line):
        LOOP: [exact loop content] | REASON: [brief reason]
        """

        do {
            let response = try await sendMessage(prompt, maxTokens: 300)
            return parseResurfacingSuggestions(response, loops: loops)
        } catch {
            lastError = error.localizedDescription
            return generateLocalResurfacing(loops: loops)
        }
    }

    private func parseResurfacingSuggestions(_ response: String, loops: [OpenLoopModel]) -> [ResurfacingSuggestion] {
        var suggestions: [ResurfacingSuggestion] = []

        for line in response.components(separatedBy: "\n") {
            if line.contains("LOOP:") && line.contains("REASON:") {
                let parts = line.components(separatedBy: "|")
                if parts.count >= 2 {
                    let loopPart = parts[0].replacingOccurrences(of: "LOOP:", with: "").trimmingCharacters(in: .whitespaces)
                    let reasonPart = parts[1].replacingOccurrences(of: "REASON:", with: "").trimmingCharacters(in: .whitespaces)

                    // Find matching loop
                    if let matchedLoop = loops.first(where: { $0.content.lowercased().contains(loopPart.lowercased().prefix(20)) }) {
                        suggestions.append(ResurfacingSuggestion(loop: matchedLoop, reason: reasonPart))
                    }
                }
            }
        }

        return suggestions
    }

    // Local fallback resurfacing (no AI)
    private func generateLocalResurfacing(loops: [OpenLoopModel]) -> [ResurfacingSuggestion] {
        let openLoops = loops.filter { !$0.isCompleted }
        var suggestions: [ResurfacingSuggestion] = []

        // High priority, oldest first
        let highPriority = openLoops.filter { $0.importance <= 2 }
            .sorted { $0.createdDate < $1.createdDate }

        if let first = highPriority.first {
            let days = Calendar.current.dateComponents([.day], from: first.createdDate, to: Date()).day ?? 0
            suggestions.append(ResurfacingSuggestion(loop: first, reason: "High priority, \(days) days old"))
        }

        // Close to completion
        let almostDone = openLoops.filter { $0.progress >= 0.7 && $0.progress < 1.0 }
            .sorted { $0.progress > $1.progress }

        if let first = almostDone.first {
            suggestions.append(ResurfacingSuggestion(loop: first, reason: "Almost complete (\(Int(first.progress * 100))%)"))
        }

        // Due soon
        let dueSoon = openLoops.filter { $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        if let first = dueSoon.first, let due = first.dueDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
            if days <= 3 {
                suggestions.append(ResurfacingSuggestion(loop: first, reason: days == 0 ? "Due today!" : "Due in \(days) days"))
            }
        }

        return Array(suggestions.prefix(3))
    }

    // MARK: - Schedule Suggestions
    func getSchedulingSuggestions(loops: [OpenLoopModel], existingEvents: [String]) async -> [ScheduleSuggestion] {
        let openLoops = loops.filter { !$0.isCompleted }
        guard !openLoops.isEmpty else { return [] }

        guard hasAPIKey else { return generateLocalScheduleSuggestions(loops: openLoops) }

        let loopSummary = openLoops.prefix(15).map { loop in
            let sphere = loop.sphere?.name ?? "Unassigned"
            let est = loop.estimatedMinutes.map { "\($0)m" } ?? "unknown"
            let due = loop.dueDate.map { "due \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "no due date"
            return "- \(loop.content) [Sphere: \(sphere), Priority: \(loop.importance), Est: \(est), \(due), Progress: \(Int(loop.progress * 100))%]"
        }.joined(separator: "\n")

        let eventSummary = existingEvents.isEmpty ? "No events scheduled yet." : existingEvents.joined(separator: "\n")

        let prompt = """
        You are a scheduling assistant. Suggest which tasks the user should time-block into their calendar today.

        Today's existing events:
        \(eventSummary)

        Open tasks:
        \(loopSummary)

        Pick up to 3 tasks that should be scheduled today. Consider priority, due dates, and gaps in the calendar.

        Respond in this exact format for each (one per line):
        TASK: [exact task content] | TIME: [suggested time like 9:00 AM] | DURATION: [minutes like 60] | WHY: [brief reason]
        """

        do {
            let response = try await sendMessage(prompt, maxTokens: 300)
            return parseScheduleSuggestions(response, loops: openLoops)
        } catch {
            lastError = error.localizedDescription
            return generateLocalScheduleSuggestions(loops: openLoops)
        }
    }

    private func parseScheduleSuggestions(_ response: String, loops: [OpenLoopModel]) -> [ScheduleSuggestion] {
        var suggestions: [ScheduleSuggestion] = []

        for line in response.components(separatedBy: "\n") {
            if line.contains("TASK:") && line.contains("WHY:") {
                let parts = line.components(separatedBy: "|")
                if parts.count >= 4 {
                    let taskPart = parts[0].replacingOccurrences(of: "TASK:", with: "").trimmingCharacters(in: .whitespaces)
                    let timePart = parts[1].replacingOccurrences(of: "TIME:", with: "").trimmingCharacters(in: .whitespaces)
                    let durationPart = parts[2].replacingOccurrences(of: "DURATION:", with: "").trimmingCharacters(in: .whitespaces)
                    let whyPart = parts[3].replacingOccurrences(of: "WHY:", with: "").trimmingCharacters(in: .whitespaces)

                    if let matchedLoop = loops.first(where: { $0.content.lowercased().contains(taskPart.lowercased().prefix(20)) }) {
                        let duration = Int(durationPart.replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces)) ?? matchedLoop.estimatedMinutes ?? 60
                        suggestions.append(ScheduleSuggestion(loop: matchedLoop, suggestedTime: timePart, suggestedDuration: duration, reason: whyPart))
                    }
                }
            }
        }

        return suggestions
    }

    private func generateLocalScheduleSuggestions(loops: [OpenLoopModel]) -> [ScheduleSuggestion] {
        var suggestions: [ScheduleSuggestion] = []
        let cal = Calendar.current
        var nextHour = max(cal.component(.hour, from: Date()) + 1, 9)

        // Due today / overdue first
        let dueToday = loops.filter { loop in
            guard let due = loop.dueDate else { return false }
            return cal.isDateInToday(due) || due < Date()
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        for loop in dueToday.prefix(2) {
            let timeStr = formatHour(nextHour)
            let dur = loop.estimatedMinutes ?? 60
            let reason = loop.dueDate.map { $0 < Date() ? "Overdue" : "Due today" } ?? "Due today"
            suggestions.append(ScheduleSuggestion(loop: loop, suggestedTime: timeStr, suggestedDuration: dur, reason: reason))
            nextHour += max(dur / 60, 1)
        }

        // High priority
        let highPriority = loops.filter { $0.importance <= 2 && !dueToday.contains(where: { $0.id == $0.id }) }
            .sorted { $0.importance < $1.importance }

        for loop in highPriority.prefix(3 - suggestions.count) {
            let timeStr = formatHour(nextHour)
            let dur = loop.estimatedMinutes ?? 60
            suggestions.append(ScheduleSuggestion(loop: loop, suggestedTime: timeStr, suggestedDuration: dur, reason: "High priority"))
            nextHour += max(dur / 60, 1)
        }

        return Array(suggestions.prefix(3))
    }

    private func formatHour(_ hour: Int) -> String {
        let h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let period = hour >= 12 ? "PM" : "AM"
        return "\(h):00 \(period)"
    }

    // MARK: - Chat / Mind Interface (Personalized)

    func chat(message: String, context: ChatContext) async -> String {
        guard hasAPIKey else {
            return "Please add your Claude API key in Settings to enable AI features."
        }

        // Get personalized system prompt if available
        let personalization = PersonalizationService.shared
        let systemPrompt: String

        if personalization.isProfileLoaded, let _ = personalization.currentProfile {
            // Use personalized prompt from PersonalizationService
            systemPrompt = personalization.buildPersonalizedSystemPrompt() + """

            Current context: \(context.sphereCount) spheres, \(context.openLoopCount) open loops, \(context.completedThisWeek) completed this week.
            Top spheres: \(context.topSpheres.joined(separator: ", ")).
            """
        } else {
            // Fallback to default prompt
            systemPrompt = """
            You are a gentle, reliable companion in the "Spheres" productivity app. Think of yourself as a calm, thoughtful assistant who genuinely wants to help.

            User context: \(context.sphereCount) spheres, \(context.openLoopCount) open loops, \(context.completedThisWeek) completed this week. Top spheres: \(context.topSpheres.joined(separator: ", ")).

            Guidelines:
            - Speak gently and warmly, like a supportive friend
            - Keep responses brief (2-3 sentences) and calming
            - Offer suggestions softly, never pushy or demanding
            - Acknowledge without judgment
            - Avoid triggering stress - be reassuring, not urgent
            """
        }

        let fullPrompt = "\(systemPrompt)\n\nUser: \(message)"

        do {
            let response = try await sendMessage(fullPrompt, maxTokens: 200)

            // Extract and store memories from the user's message
            personalization.processMessage(message)

            return response
        } catch {
            lastError = error.localizedDescription
            return "I encountered an error: \(error.localizedDescription)"
        }
    }

    // MARK: - Values-Aware Classification

    /// Classifies an inbox item with values-based sphere suggestions
    func classifyWithValues(_ content: String, spheres: [SphereModel]) async -> (sphere: SphereModel?, confidence: Double) {
        guard hasAPIKey else { return (nil, 0.0) }

        let personalization = PersonalizationService.shared
        var valuesContext = ""

        if let profile = personalization.currentProfile {
            let topValues = profile.topValues(count: 3)
            if !topValues.isEmpty {
                valuesContext = "\nUser's core values: \(topValues.map { $0.rawValue }.joined(separator: ", "))"
            }
        }

        let sphereList = spheres.map { sphere -> String in
            let boost = personalization.valueAlignmentBoost(for: sphere)
            let priority = boost > 1.0 ? " (aligned with user values)" : ""
            return "\(sphere.name): \(sphere.sphereDescription)\(priority)"
        }.joined(separator: "\n")

        let prompt = """
        You are a helpful assistant that categorizes tasks into life spheres.
        \(valuesContext)

        Available spheres:
        \(sphereList)

        Task to categorize: "\(content)"

        Respond in this format:
        SPHERE: [sphere name]
        CONFIDENCE: [0.0 to 1.0]
        """

        do {
            let response = try await sendMessage(prompt, maxTokens: 100)
            return parseClassificationResponse(response, spheres: spheres)
        } catch {
            lastError = error.localizedDescription
            return (nil, 0.0)
        }
    }

    private func parseClassificationResponse(_ response: String, spheres: [SphereModel]) -> (SphereModel?, Double) {
        var sphereName: String?
        var confidence: Double = 0.7  // Default confidence

        for line in response.components(separatedBy: "\n") {
            if line.hasPrefix("SPHERE:") {
                sphereName = line.replacingOccurrences(of: "SPHERE:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("CONFIDENCE:") {
                let confStr = line.replacingOccurrences(of: "CONFIDENCE:", with: "").trimmingCharacters(in: .whitespaces)
                confidence = Double(confStr) ?? 0.7
            }
        }

        let matchedSphere = spheres.first { $0.name.lowercased() == sphereName?.lowercased() }
        return (matchedSphere, confidence)
    }

    // MARK: - Proactive Scheduling Message
    func generateSchedulingSuggestion(loop: OpenLoopModel, suggestedTime: Date, duration: Int) async -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeStr = timeFormatter.string(from: suggestedTime)

        let sphereName = loop.sphere?.name ?? "your tasks"
        let daysOld = Calendar.current.dateComponents([.day], from: loop.createdDate, to: Date()).day ?? 0

        // Build context about the task
        var context = "Task: \"\(loop.content)\""
        context += "\nSphere: \(sphereName)"
        context += "\nPriority: \(loop.importance) (1=highest, 5=lowest)"
        context += "\nProgress: \(Int(loop.progress * 100))%"
        context += "\nDays since created: \(daysOld)"
        if let est = loop.estimatedMinutes {
            context += "\nEstimated time: \(est) minutes"
        }
        if let due = loop.dueDate {
            let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
            if daysUntilDue < 0 {
                context += "\nStatus: OVERDUE by \(abs(daysUntilDue)) days!"
            } else if daysUntilDue == 0 {
                context += "\nStatus: Due TODAY"
            } else {
                context += "\nStatus: Due in \(daysUntilDue) days"
            }
        }

        guard hasAPIKey else {
            // Fallback without AI
            if let due = loop.dueDate {
                let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                if daysUntilDue < 0 {
                    return "Hey! \"\(loop.content)\" is overdue. Want to knock it out at \(timeStr)? That's \(duration) minutes blocked off just for this."
                } else if daysUntilDue == 0 {
                    return "Heads up — \"\(loop.content)\" is due today! I found a \(duration)-minute slot at \(timeStr). Lock it in?"
                }
            }
            if loop.importance <= 2 {
                return "You marked \"\(loop.content)\" as high priority but it's been sitting for \(daysOld) days. How about \(timeStr)? I'll block \(duration) minutes."
            }
            return "Found a good time for \"\(loop.content)\" — \(timeStr) works with your calendar. That's \(duration) minutes. Sound good?"
        }

        let prompt = """
        You're a gentle, supportive companion in the Spheres app. Write a soft, friendly message (2-3 sentences) gently suggesting the user might want to schedule this task.

        Task details:
        \(context)

        Suggested time: \(timeStr)
        Duration: \(duration) minutes

        Guidelines:
        - Be warm and gentle, like a caring friend
        - Suggest softly, never pushy ("maybe...", "when you're ready...", "no pressure but...")
        - Mention context naturally without making it feel urgent
        - Keep it calming and reassuring, never stressful
        """

        do {
            let response = try await sendMessage(prompt, maxTokens: 150)
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            // Fallback on error
            return "I found a \(duration)-minute slot at \(timeStr) for \"\(loop.content)\". Want me to add it to your calendar?"
        }
    }

    // MARK: - Pattern Recognition
    func suggestNewSphere(from loops: [OpenLoopModel], existingSpheres: [SphereModel]) async -> SphereSuggestion? {
        guard hasAPIKey else { return nil }

        let unassignedLoops = loops.filter { $0.sphere == nil }.map { $0.content }
        guard unassignedLoops.count >= 3 else { return nil }

        let existingNames = existingSpheres.map { $0.name }.joined(separator: ", ")
        let loopList = unassignedLoops.prefix(10).joined(separator: "\n- ")

        let prompt = """
        You are analyzing unassigned tasks to suggest new life spheres.

        Existing spheres: \(existingNames)

        Unassigned tasks:
        - \(loopList)

        If these tasks suggest a new sphere that doesn't exist, respond in this format:
        NAME: [sphere name]
        ICON: [SF Symbol name like heart.fill, briefcase.fill, etc.]
        DESCRIPTION: [brief description]

        If no new sphere is needed, respond with: NONE
        """

        do {
            let response = try await sendMessage(prompt, maxTokens: 150)
            return parseSphereSuggestion(response)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private func parseSphereSuggestion(_ response: String) -> SphereSuggestion? {
        if response.contains("NONE") { return nil }

        var name: String?
        var icon: String?
        var description: String?

        for line in response.components(separatedBy: "\n") {
            if line.starts(with: "NAME:") {
                name = line.replacingOccurrences(of: "NAME:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.starts(with: "ICON:") {
                icon = line.replacingOccurrences(of: "ICON:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.starts(with: "DESCRIPTION:") {
                description = line.replacingOccurrences(of: "DESCRIPTION:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }

        guard let n = name, let i = icon, let d = description else { return nil }
        return SphereSuggestion(name: n, icon: i, description: d)
    }

    // MARK: - API Communication
    private func sendMessage(_ content: String, maxTokens: Int) async throws -> String {
        try await sendMessage(content, maxTokens: maxTokens, model: "claude-3-haiku-20240307")
    }

    /// Send a message with a specific model and optional system prompt (used by Smart Setup)
    func sendStructuredMessage(_ content: String, systemPrompt: String? = nil, maxTokens: Int, model: String = "claude-sonnet-4-6") async throws -> String {
        try await sendMessage(content, maxTokens: maxTokens, model: model, systemPrompt: systemPrompt)
    }

    private func sendMessage(_ content: String, maxTokens: Int, model: String, systemPrompt: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIError.noAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": content]
            ]
        ]

        if let systemPrompt = systemPrompt {
            body["system"] = systemPrompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        isProcessing = true
        defer { isProcessing = false }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let firstContent = contentArray.first,
              let text = firstContent["text"] as? String else {
            throw AIError.invalidResponse
        }

        return text
    }
}

// MARK: - Supporting Types
struct ResurfacingSuggestion: Identifiable {
    let id = UUID()
    let loop: OpenLoopModel
    let reason: String
}

struct ScheduleSuggestion: Identifiable {
    let id = UUID()
    let loop: OpenLoopModel
    let suggestedTime: String
    let suggestedDuration: Int
    let reason: String
}

struct SphereSuggestion {
    let name: String
    let icon: String
    let description: String
}

struct ChatContext {
    let sphereCount: Int
    let openLoopCount: Int
    let completedThisWeek: Int
    let topSpheres: [String]
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

enum AIError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key configured"
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from API"
        case .apiError(let message): return message
        }
    }
}
