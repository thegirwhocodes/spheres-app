//
//  NotesAdapter.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Extracts tasks from Apple Notes via AppleScript
//

import Foundation

class NotesAdapter: SourceAdapter {
    let source: TaskSource = .notes

    // Patterns that indicate a task
    private let taskPatterns = [
        "- [ ]",      // Markdown checkbox
        "☐",          // Unicode checkbox
        "TODO:",
        "TODO",
        "TASK:",
        "ACTION:",
        "• ",         // Bullet point followed by action word
    ]

    private let actionStarters = [
        "buy", "call", "email", "send", "schedule", "book", "order",
        "review", "read", "write", "complete", "finish", "start",
        "fix", "update", "check", "confirm", "prepare", "create",
        "research", "find", "get", "pick up", "submit", "pay"
    ]

    func checkPermissions() async -> Bool {
        let script = """
        tell application "Notes"
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
        return await checkPermissions()
    }

    func extractTasks(since: Date?, limit: Int?) async throws -> [ExtractedTask] {
        let maxNotes = limit ?? 30

        // AppleScript to get recent notes
        let script = """
        tell application "Notes"
            set output to ""
            set noteList to notes of default account
            set noteCount to count of noteList
            if noteCount > \(maxNotes) then set noteCount to \(maxNotes)

            repeat with i from 1 to noteCount
                set theNote to item i of noteList
                set noteId to id of theNote
                set noteName to name of theNote
                set noteBody to body of theNote
                set noteMod to modification date of theNote

                set output to output & "---NOTE---" & return
                set output to output & "ID:" & noteId & return
                set output to output & "NAME:" & noteName & return
                set output to output & "MODIFIED:" & (noteMod as string) & return
                set output to output & "BODY:" & noteBody & return
            end repeat

            return output
        end tell
        """

        let result = try await runAppleScript(script)
        return parseNotesOutput(result, since: since)
    }

    func markAsProcessed(sourceId: String) async {
        // Could add a tag or move the task line
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

    private func parseNotesOutput(_ output: String, since: Date?) -> [ExtractedTask] {
        var tasks: [ExtractedTask] = []
        let notes = output.components(separatedBy: "---NOTE---").filter { !$0.isEmpty }

        for noteStr in notes {
            let noteTasks = parseNote(noteStr, since: since)
            tasks.append(contentsOf: noteTasks)
        }

        return tasks
    }

    private func parseNote(_ noteStr: String, since: Date?) -> [ExtractedTask] {
        var tasks: [ExtractedTask] = []

        let lines = noteStr.components(separatedBy: .newlines)

        var id = ""
        var name = ""
        var body = ""

        var inBody = false
        for line in lines {
            if line.hasPrefix("ID:") {
                id = String(line.dropFirst(3))
            } else if line.hasPrefix("NAME:") {
                name = String(line.dropFirst(5))
            } else if line.hasPrefix("BODY:") {
                body = String(line.dropFirst(5))
                inBody = true
            } else if inBody {
                body += "\n" + line
            }
        }

        guard !id.isEmpty else { return [] }

        // Strip HTML tags from body
        let cleanBody = body.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Find task-like lines in the body
        let bodyLines = cleanBody.components(separatedBy: .newlines)

        for (index, line) in bodyLines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let task = extractTaskFromLine(trimmed, noteId: id, noteName: name, lineIndex: index) {
                tasks.append(task)
            }
        }

        return tasks
    }

    private func extractTaskFromLine(_ line: String, noteId: String, noteName: String, lineIndex: Int) -> ExtractedTask? {
        let lowercased = line.lowercased()
        var confidence = 0.0

        // Check for explicit task patterns
        for pattern in taskPatterns {
            if line.contains(pattern) || lowercased.contains(pattern.lowercased()) {
                confidence = 0.9
                break
            }
        }

        // Check for action starters
        if confidence < 0.7 {
            for starter in actionStarters {
                if lowercased.hasPrefix(starter) || lowercased.hasPrefix("- \(starter)") || lowercased.hasPrefix("• \(starter)") {
                    confidence = max(confidence, 0.7)
                    break
                }
            }
        }

        // Skip if not task-like enough
        guard confidence >= 0.7 else { return nil }

        // Clean up the task content
        var content = line

        // Remove checkbox patterns
        content = content.replacingOccurrences(of: "- [ ]", with: "")
        content = content.replacingOccurrences(of: "☐", with: "")
        content = content.replacingOccurrences(of: "TODO:", with: "")
        content = content.replacingOccurrences(of: "TODO", with: "")
        content = content.trimmingCharacters(in: .whitespaces)

        // Remove leading bullets
        if content.hasPrefix("- ") {
            content = String(content.dropFirst(2))
        }
        if content.hasPrefix("• ") {
            content = String(content.dropFirst(2))
        }

        guard !content.isEmpty else { return nil }

        return ExtractedTask(
            content: content,
            source: .notes,
            sourceId: "\(noteId):\(lineIndex)",
            extractedAt: Date(),
            confidence: confidence,
            suggestedSphere: nil,
            suggestedPriority: nil,
            context: "From note: \(noteName)"
        )
    }
}
