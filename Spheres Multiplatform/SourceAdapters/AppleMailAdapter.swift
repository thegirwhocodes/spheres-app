//
//  AppleMailAdapter.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Extracts tasks from Apple Mail via AppleScript
//

import Foundation

class AppleMailAdapter: SourceAdapter {
    let source: TaskSource = .appleMail

    // Keywords that suggest a task/action item
    private let actionKeywords = [
        "please", "could you", "can you", "action required", "action needed",
        "deadline", "due", "by tomorrow", "by monday", "by friday", "asap",
        "urgent", "important", "follow up", "following up", "reminder",
        "todo", "to do", "to-do", "task", "schedule", "meeting request",
        "review", "approve", "sign", "complete", "submit", "send"
    ]

    func checkPermissions() async -> Bool {
        // Check if we have automation permission for Mail
        // This is tricky - we might need to try running a simple script
        let script = """
        tell application "Mail"
            return name
        end tell
        """

        do {
            _ = try await runAppleScript(script)
            return true
        } catch {
            return false
        }
    }

    func requestPermissions() async -> Bool {
        // Trigger the permission dialog by running a script
        return await checkPermissions()
    }

    func extractTasks(since: Date?, limit: Int?) async throws -> [ExtractedTask] {
        let maxMessages = limit ?? 50

        // AppleScript to get recent unread messages
        let script = """
        tell application "Mail"
            set output to ""
            set msgList to (messages of inbox whose read status is false)
            set msgCount to count of msgList
            if msgCount > \(maxMessages) then set msgCount to \(maxMessages)

            repeat with i from 1 to msgCount
                set msg to item i of msgList
                set msgId to message id of msg
                set msgSubject to subject of msg
                set msgSender to sender of msg
                set msgDate to date received of msg
                -- Get first 500 chars of content
                try
                    set msgContent to text 1 thru 500 of (content of msg)
                on error
                    set msgContent to content of msg
                end try

                set output to output & "---MESSAGE---" & return
                set output to output & "ID:" & msgId & return
                set output to output & "SUBJECT:" & msgSubject & return
                set output to output & "SENDER:" & msgSender & return
                set output to output & "DATE:" & (msgDate as string) & return
                set output to output & "CONTENT:" & msgContent & return
            end repeat

            return output
        end tell
        """

        let result = try await runAppleScript(script)
        return parseMailOutput(result, since: since)
    }

    func markAsProcessed(sourceId: String) async {
        // Could add a flag to the email or move to a folder
        // For now, we just track it in SourceAdapterManager
    }

    private func runAppleScript(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let output = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: SourceAdapterError.scriptExecutionFailed(message))
                } else if let result = output?.stringValue {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    private func parseMailOutput(_ output: String, since: Date?) -> [ExtractedTask] {
        var tasks: [ExtractedTask] = []
        let messages = output.components(separatedBy: "---MESSAGE---").filter { !$0.isEmpty }

        for messageStr in messages {
            guard let task = parseMessage(messageStr, since: since) else { continue }
            tasks.append(task)
        }

        return tasks
    }

    private func parseMessage(_ messageStr: String, since: Date?) -> ExtractedTask? {
        let lines = messageStr.components(separatedBy: .newlines)

        var id = ""
        var subject = ""
        var sender = ""
        var content = ""

        for line in lines {
            if line.hasPrefix("ID:") {
                id = String(line.dropFirst(3))
            } else if line.hasPrefix("SUBJECT:") {
                subject = String(line.dropFirst(8))
            } else if line.hasPrefix("SENDER:") {
                sender = String(line.dropFirst(7))
            } else if line.hasPrefix("CONTENT:") {
                content = String(line.dropFirst(8))
            }
        }

        guard !id.isEmpty, !subject.isEmpty else { return nil }

        // Calculate confidence based on action keywords
        let combinedText = "\(subject) \(content)".lowercased()
        var confidence = 0.3  // Base confidence for emails

        for keyword in actionKeywords {
            if combinedText.contains(keyword) {
                confidence += 0.1
            }
        }
        confidence = min(0.95, confidence)

        // Skip if confidence is too low
        guard confidence >= 0.5 else { return nil }

        // Extract task content
        let taskContent = extractTaskContent(subject: subject, content: content)

        return ExtractedTask(
            content: taskContent,
            source: .appleMail,
            sourceId: id,
            extractedAt: Date(),
            confidence: confidence,
            suggestedSphere: nil,
            suggestedPriority: nil,
            context: "From: \(sender)\nSubject: \(subject)"
        )
    }

    private func extractTaskContent(subject: String, content: String) -> String {
        // Try to extract the most actionable part
        // For now, use the subject line

        // Remove common prefixes
        var cleanSubject = subject
        let prefixes = ["Re:", "RE:", "Fwd:", "FWD:", "[EXTERNAL]", "[External]"]
        for prefix in prefixes {
            cleanSubject = cleanSubject.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespaces)
        }

        return cleanSubject
    }
}
