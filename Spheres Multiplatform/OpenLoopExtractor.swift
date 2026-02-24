//
//  OpenLoopExtractor.swift
//  Spheres - Smart Life Manager
//
//  Extracts open loops from emails, texts, and audio recordings
//  Uses cost-effective AI models (Gemini Flash / Claude Haiku)
//

import SwiftUI
import SwiftData
import Speech
import NaturalLanguage

// MARK: - Source Types
enum OpenLoopSource: String, CaseIterable {
    case email = "Email"
    case imessage = "iMessage"
    case whatsapp = "WhatsApp"
    case recording = "Recording"
    
    var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .imessage: return "message.fill"
        case .whatsapp: return "phone.fill"
        case .recording: return "mic.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .email: return .blue
        case .imessage: return .green
        case .whatsapp: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .recording: return .orange
        }
    }
}

// MARK: - Extracted Loop
struct ExtractedLoop: Identifiable {
    let id = UUID()
    let content: String
    let source: OpenLoopSource
    let sourceDetails: String
    let suggestedSphere: String?
    let priority: Int
    let date: Date
}

// MARK: - Open Loop Extractor
@MainActor
class OpenLoopExtractor: ObservableObject {
    static let shared = OpenLoopExtractor()
    
    @Published var isProcessing = false
    @Published var lastError: String?
    @Published var extractedLoops: [ExtractedLoop] = []
    
    // Settings
    @AppStorage("messageHistoryDays") var messageHistoryDays: Int = 3
    @AppStorage("emailProcessingEnabled") var emailProcessingEnabled: Bool = false
    @AppStorage("imessageProcessingEnabled") var imessageProcessingEnabled: Bool = false
    @AppStorage("whatsappProcessingEnabled") var whatsappProcessingEnabled: Bool = false
    @AppStorage("recordingProcessingEnabled") var recordingProcessingEnabled: Bool = false
    @AppStorage("aiModelPreference") var aiModelPreference: String = "gemini-flash" // gemini-flash or claude-haiku
    
    // API Keys
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = ""
    @AppStorage("claudeAPIKey") private var claudeAPIKey: String = ""
    
    var hasAIKey: Bool {
        !geminiAPIKey.isEmpty || !claudeAPIKey.isEmpty
    }
    
    private init() {
        // Request speech recognition permission on init
        requestSpeechPermission()
    }
    
    // MARK: - API Key Management
    func setGeminiKey(_ key: String) {
        geminiAPIKey = key
    }
    
    func setClaudeKey(_ key: String) {
        claudeAPIKey = key
    }
    
    func getPreferredKey() -> (key: String, type: String)? {
        if aiModelPreference == "gemini-flash" && !geminiAPIKey.isEmpty {
            return (geminiAPIKey, "gemini")
        } else if !claudeAPIKey.isEmpty {
            return (claudeAPIKey, "claude")
        } else if !geminiAPIKey.isEmpty {
            return (geminiAPIKey, "gemini")
        }
        return nil
    }
    
    // MARK: - Speech Permission
    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            print("Speech recognition permission: \(status)")
        }
    }
    
    // MARK: - Process All Sources
    func processAllSources(modelContext: ModelContext) async {
        guard hasAIKey else {
            lastError = "No AI API key configured"
            return
        }

        isProcessing = true
        extractedLoops = []

        if emailProcessingEnabled {
            await processEmails()
        }

        if imessageProcessingEnabled {
            await processIMessages()
        }

        if whatsappProcessingEnabled {
            await processWhatsApp()
        }

        // Import all extracted loops to inbox
        for extracted in extractedLoops {
            importToInbox(extracted, modelContext: modelContext)
        }

        isProcessing = false
    }
    
    // MARK: - Email Processing
    func processEmails() async {
        print("[OpenLoopExtractor] Processing emails via AppleMailAdapter...")

        let adapter = AppleMailAdapter()

        guard await adapter.checkPermissions() else {
            print("[OpenLoopExtractor] No permission to access Mail app")
            lastError = "Mail access not permitted. Grant permission in System Settings > Privacy & Security > Automation."
            return
        }

        do {
            let tasks = try await adapter.extractTasks(since: nil, limit: 50)
            print("[OpenLoopExtractor] Found \(tasks.count) potential tasks from Mail")

            for task in tasks {
                let extracted = ExtractedLoop(
                    content: task.content,
                    source: .email,
                    sourceDetails: task.context ?? "Apple Mail",
                    suggestedSphere: task.suggestedSphere,
                    priority: task.confidence > 0.7 ? 2 : 3,
                    date: task.extractedAt
                )
                extractedLoops.append(extracted)
            }
        } catch {
            print("[OpenLoopExtractor] Error processing emails: \(error)")
            lastError = "Failed to process emails: \(error.localizedDescription)"
        }
    }

    // MARK: - iMessage Processing
    func processIMessages() async {
        print("[OpenLoopExtractor] Processing iMessages via IMessageAdapter...")

        let adapter = IMessageAdapter()

        guard await adapter.checkPermissions() else {
            print("[OpenLoopExtractor] No permission to access Messages")
            lastError = "iMessage access requires Full Disk Access. Grant in System Settings > Privacy & Security > Full Disk Access."
            return
        }

        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -messageHistoryDays, to: Date())

        do {
            let tasks = try await adapter.extractTasks(since: cutoffDate, limit: 100)
            print("[OpenLoopExtractor] Found \(tasks.count) potential tasks from iMessages")

            for task in tasks {
                let extracted = ExtractedLoop(
                    content: task.content,
                    source: .imessage,
                    sourceDetails: task.context ?? "iMessage",
                    suggestedSphere: task.suggestedSphere,
                    priority: task.confidence > 0.7 ? 2 : 3,
                    date: task.extractedAt
                )
                extractedLoops.append(extracted)
            }
        } catch {
            print("[OpenLoopExtractor] Error processing iMessages: \(error)")
            lastError = "Failed to process iMessages: \(error.localizedDescription)"
        }
    }

    // MARK: - WhatsApp Processing
    func processWhatsApp() async {
        print("[OpenLoopExtractor] WhatsApp processing not available")
        // WhatsApp doesn't have a public API for messages
        // Would need WhatsApp Business API (requires Meta approval) or backup parsing
        // Left as placeholder for future integration
    }
    
    // MARK: - Audio Recording Processing
    func processAudioRecording(url: URL) async throws -> [ExtractedLoop] {
        guard recordingProcessingEnabled else {
            return []
        }
        
        print("[OpenLoopExtractor] Processing audio: \(url.lastPathComponent)")
        
        // Step 1: Transcribe using Speech framework (free, on-device)
        let transcription = try await transcribeAudio(url: url)
        
        // Step 2: Extract action items using AI (cost-effective model)
        let loops = try await extractLoopsFromText(transcription, source: .recording, details: url.lastPathComponent)
        
        return loops
    }
    
    // MARK: - Speech-to-Text (Free, On-Device)
    private func transcribeAudio(url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw ExtractorError.speechRecognizerUnavailable
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true // Free, private
        
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
    
    // MARK: - AI Extraction (Low-Cost Model)
    private func extractLoopsFromText(_ text: String, source: OpenLoopSource, details: String) async throws -> [ExtractedLoop] {
        guard let (apiKey, modelType) = getPreferredKey() else {
            throw ExtractorError.noAPIKey
        }
        
        let prompt = """
        Extract action items and open loops from the following text. 
        Return ONLY a JSON array with objects containing:
        - "content": The task/action item (clear, actionable)
        - "priority": 1 (urgent), 2 (high), 3 (medium), 4 (low), or 5 (optional)
        - "sphere": Suggested sphere (Spiritual, Health, Family, Career, Education, Creative, Finance, Social)
        
        Text to analyze:
        \"\"\"
        \(text.prefix(8000)) // Limit to reduce API cost
        \"\"\"
        
        Return format: [{"content": "...", "priority": 1, "sphere": "..."}]
        If no action items, return: []
        """
        
        var extractedLoops: [ExtractedLoop] = []
        
        if modelType == "gemini" {
            extractedLoops = try await callGeminiAPI(prompt: prompt, apiKey: apiKey, source: source, details: details)
        } else {
            extractedLoops = try await callClaudeAPI(prompt: prompt, apiKey: apiKey, source: source, details: details)
        }
        
        return extractedLoops
    }
    
    // MARK: - Gemini Flash API (Cheaper Option)
    private func callGeminiAPI(prompt: String, apiKey: String, source: OpenLoopSource, details: String) async throws -> [ExtractedLoop] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=\(apiKey)")!
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.1, // Low temp = more consistent, cheaper
                "maxOutputTokens": 1024
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ExtractorError.apiError("Gemini API error")
        }
        
        // Parse response and extract loops
        return parseAIResponse(data: data, source: source, details: details)
    }
    
    // MARK: - Claude Haiku API (Alternative)
    private func callClaudeAPI(prompt: String, apiKey: String, source: OpenLoopSource, details: String) async throws -> [ExtractedLoop] {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        
        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307", // Cheapest Claude model
            "max_tokens": 1024,
            "temperature": 0.1,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ExtractorError.apiError("Claude API error")
        }
        
        return parseAIResponse(data: data, source: source, details: details)
    }
    
    // MARK: - Parse AI Response
    private func parseAIResponse(data: Data, source: OpenLoopSource, details: String) -> [ExtractedLoop] {
        // Try to extract JSON from response
        guard let jsonString = String(data: data, encoding: .utf8) else {
            return []
        }
        
        // Look for JSON array in response
        if let jsonStart = jsonString.range(of: "["),
           let jsonEnd = jsonString.range(of: "]", range: jsonStart.upperBound..<jsonString.endIndex) {
            let jsonArray = String(jsonString[jsonStart.lowerBound...jsonEnd.upperBound])
            
            if let jsonData = jsonArray.data(using: .utf8),
               let items = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                
                return items.compactMap { item in
                    guard let content = item["content"] as? String else { return nil }
                    let priority = item["priority"] as? Int ?? 3
                    let sphere = item["sphere"] as? String
                    
                    return ExtractedLoop(
                        content: content,
                        source: source,
                        sourceDetails: details,
                        suggestedSphere: sphere,
                        priority: priority,
                        date: Date()
                    )
                }
            }
        }
        
        return []
    }
    
    // MARK: - Import to Inbox
    func importToInbox(_ extracted: ExtractedLoop, modelContext: ModelContext) {
        let inboxItem = InboxItemModel(
            content: "[\(extracted.source.rawValue)] \(extracted.content)",
            suggestedSphereId: nil // Could map sphere name to actual sphere
        )
        modelContext.insert(inboxItem)
        try? modelContext.save()
    }
}

// MARK: - Errors
enum ExtractorError: Error {
    case speechRecognizerUnavailable
    case noAPIKey
    case apiError(String)
    case parsingError
}
