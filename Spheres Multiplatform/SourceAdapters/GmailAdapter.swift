//
//  GmailAdapter.swift
//  Spheres - Smart Life Manager
//
//  Extracts tasks from Gmail via the Gmail REST API.
//  Uses GoogleAuthService for OAuth 2.0 authentication.
//

import Foundation

class GmailAdapter: SourceAdapter {
    let source: TaskSource = .gmail

    private let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"
    private let authService = GoogleAuthService.shared

    // Keywords that suggest a task/action item (shared with AppleMailAdapter)
    private let actionKeywords = [
        "please", "could you", "can you", "action required", "action needed",
        "deadline", "due", "by tomorrow", "by monday", "by friday", "asap",
        "urgent", "important", "follow up", "following up", "reminder",
        "todo", "to do", "to-do", "task", "schedule", "meeting request",
        "review", "approve", "sign", "complete", "submit", "send",
        "rsvp", "confirm", "reply", "respond", "update", "prepare"
    ]

    func checkPermissions() async -> Bool {
        return await MainActor.run { authService.isSignedIn }
    }

    func requestPermissions() async -> Bool {
        do {
            try await authService.signIn()
            return true
        } catch {
            print("DEBUG: Gmail sign-in failed: \(error)")
            return false
        }
    }

    func extractTasks(since: Date?, limit: Int?) async throws -> [ExtractedTask] {
        let token = try await authService.getValidAccessToken()
        let maxMessages = min(limit ?? 50, 50)

        // Step 1: List recent inbox messages
        let messageIds = try await listMessages(token: token, maxResults: maxMessages)
        print("DEBUG: Gmail listed \(messageIds.count) messages")

        guard !messageIds.isEmpty else { return [] }

        // Step 2: Fetch metadata for each message (in parallel batches)
        var tasks: [ExtractedTask] = []
        let batchSize = 10

        for batchStart in stride(from: 0, to: messageIds.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, messageIds.count)
            let batch = Array(messageIds[batchStart..<batchEnd])

            let batchResults = try await withThrowingTaskGroup(of: ExtractedTask?.self) { group in
                for id in batch {
                    group.addTask {
                        try await self.fetchMessageMetadata(id: id, token: token, since: since)
                    }
                }

                var results: [ExtractedTask] = []
                for try await result in group {
                    if let task = result {
                        results.append(task)
                    }
                }
                return results
            }

            tasks.append(contentsOf: batchResults)
        }

        print("DEBUG: Gmail extracted \(tasks.count) task candidates from \(messageIds.count) messages")
        return tasks
    }

    func markAsProcessed(sourceId: String) async {
        // Track in SourceAdapterManager (no Gmail modifications needed)
    }

    // MARK: - Gmail API Calls

    private func listMessages(token: String, maxResults: Int) async throws -> [String] {
        var components = URLComponents(string: "\(baseURL)/messages")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "newer_than:30d in:inbox"),
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SourceAdapterError.sourceNotAvailable("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            // Token expired mid-request
            throw SourceAdapterError.permissionDenied
        }

        guard httpResponse.statusCode == 200 else {
            throw SourceAdapterError.sourceNotAvailable("Gmail API returned \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            return [] // No messages
        }

        return messages.compactMap { $0["id"] as? String }
    }

    private func fetchMessageMetadata(id: String, token: String, since: Date?) async throws -> ExtractedTask? {
        var components = URLComponents(string: "\(baseURL)/messages/\(id)")!
        components.queryItems = [
            URLQueryItem(name: "format", value: "METADATA"),
            URLQueryItem(name: "metadataHeaders", value: "Subject"),
            URLQueryItem(name: "metadataHeaders", value: "From"),
            URLQueryItem(name: "metadataHeaders", value: "Date"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Parse headers
        guard let payload = json["payload"] as? [String: Any],
              let headers = payload["headers"] as? [[String: String]] else {
            return nil
        }

        var subject = ""
        var sender = ""

        for header in headers {
            if header["name"] == "Subject" { subject = header["value"] ?? "" }
            if header["name"] == "From" { sender = header["value"] ?? "" }
        }

        let snippet = json["snippet"] as? String ?? ""

        // Check date filter
        if let since = since, let internalDateStr = json["internalDate"] as? String,
           let internalDateMs = Double(internalDateStr) {
            let messageDate = Date(timeIntervalSince1970: internalDateMs / 1000.0)
            if messageDate < since { return nil }
        }

        guard !subject.isEmpty else { return nil }

        // Score confidence based on action keywords
        let combinedText = "\(subject) \(snippet)".lowercased()
        var confidence = 0.3 // Base confidence for emails

        for keyword in actionKeywords {
            if combinedText.contains(keyword) {
                confidence += 0.1
            }
        }
        confidence = min(0.95, confidence)

        // Skip low-confidence emails
        guard confidence >= 0.5 else { return nil }

        // Clean subject
        let cleanSubject = cleanEmailSubject(subject)

        return ExtractedTask(
            content: cleanSubject,
            source: .gmail,
            sourceId: "gmail_\(id)",
            extractedAt: Date(),
            confidence: confidence,
            suggestedSphere: nil,
            suggestedPriority: nil,
            context: "From: \(sender)\nSubject: \(subject)\nPreview: \(String(snippet.prefix(100)))"
        )
    }

    // MARK: - Helpers

    private func cleanEmailSubject(_ subject: String) -> String {
        var cleaned = subject
        let prefixes = ["Re:", "RE:", "Fwd:", "FWD:", "Fw:", "FW:",
                        "[EXTERNAL]", "[External]", "[EXT]"]
        for prefix in prefixes {
            cleaned = cleaned.replacingOccurrences(of: prefix, with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}
