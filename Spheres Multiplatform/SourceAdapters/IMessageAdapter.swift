//
//  IMessageAdapter.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Extracts tasks from iMessage via SQLite (requires Full Disk Access)
//  NOTE: This adapter only works with direct distribution, not App Store
//

import Foundation
import SQLite3

class IMessageAdapter: SourceAdapter {
    let source: TaskSource = .iMessage

    // Task detection patterns
    private let taskPatterns = [
        "remind me",
        "don't forget",
        "can you",
        "could you",
        "please",
        "need to",
        "have to",
        "gotta",
        "todo",
        "to do"
    ]

    private let actionVerbs = [
        "buy", "call", "email", "send", "schedule", "book", "order",
        "review", "read", "write", "complete", "finish", "start",
        "fix", "update", "check", "confirm", "prepare", "create",
        "research", "find", "get", "pick up", "submit", "pay",
        "bring", "grab"
    ]

    // iMessage database location
    private var chatDatabasePath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Messages/chat.db")
            .path
    }

    func checkPermissions() async -> Bool {
        // Check if we can read the chat.db file
        // This requires Full Disk Access which the user must grant manually
        let path = chatDatabasePath
        return FileManager.default.isReadableFile(atPath: path)
    }

    func requestPermissions() async -> Bool {
        // We can't programmatically request Full Disk Access
        // User must go to System Preferences > Privacy & Security > Full Disk Access
        // Return current status
        return await checkPermissions()
    }

    func extractTasks(since: Date?, limit: Int?) async throws -> [ExtractedTask] {
        guard await checkPermissions() else {
            throw SourceAdapterError.permissionDenied
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(chatDatabasePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw SourceAdapterError.sourceNotAvailable("Could not open iMessage database")
        }
        defer { sqlite3_close(db) }

        // Build query for recent messages
        let sinceTimestamp = since.map { macAbsoluteTime(from: $0) } ?? 0
        let maxMessages = limit ?? 100

        // Query to get recent received messages (excluding sent by me)
        let query = """
            SELECT
                m.ROWID,
                m.guid,
                m.text,
                m.date,
                m.is_from_me,
                h.id as sender
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            WHERE m.text IS NOT NULL
                AND m.text != ''
                AND m.is_from_me = 0
                AND m.date > ?
            ORDER BY m.date DESC
            LIMIT ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw SourceAdapterError.scriptExecutionFailed("SQL prepare failed: \(error)")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(sinceTimestamp))
        sqlite3_bind_int(statement, 2, Int32(maxMessages))

        var tasks: [ExtractedTask] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let rowId = sqlite3_column_int64(statement, 0)
            let guidPtr = sqlite3_column_text(statement, 1)
            let textPtr = sqlite3_column_text(statement, 2)
            let dateValue = sqlite3_column_int64(statement, 3)
            let senderPtr = sqlite3_column_text(statement, 5)

            guard let textPtr = textPtr else { continue }

            let text = String(cString: textPtr)
            let guid = guidPtr.map { String(cString: $0) } ?? "\(rowId)"
            let sender = senderPtr.map { String(cString: $0) } ?? "Unknown"
            let messageDate = date(fromMacAbsoluteTime: Double(dateValue))

            // Analyze message for task-likeness
            if let task = extractTaskFromMessage(text, guid: guid, sender: sender, date: messageDate) {
                tasks.append(task)
            }
        }

        return tasks
    }

    func markAsProcessed(sourceId: String) async {
        // Tracked in SourceAdapterManager
    }

    // MARK: - Task Extraction

    private func extractTaskFromMessage(_ text: String, guid: String, sender: String, date: Date) -> ExtractedTask? {
        let lowercased = text.lowercased()
        var confidence = 0.0

        // Check for task patterns
        for pattern in taskPatterns {
            if lowercased.contains(pattern) {
                confidence = max(confidence, 0.75)
                break
            }
        }

        // Check for action verbs
        if confidence < 0.7 {
            for verb in actionVerbs {
                if lowercased.contains(verb) {
                    confidence = max(confidence, 0.65)
                    break
                }
            }
        }

        // Question-based requests boost confidence
        if text.contains("?") && (lowercased.contains("can you") || lowercased.contains("could you") || lowercased.contains("will you")) {
            confidence = max(confidence, 0.8)
        }

        // Skip if not task-like enough
        guard confidence >= 0.7 else { return nil }

        // Clean up content - extract the actionable part
        var content = text

        // Remove common conversational fluff
        let prefixesToRemove = [
            "hey ", "hi ", "hello ", "yo ", "btw ", "oh ", "also ",
            "can you please ", "could you please ", "can you ", "could you ",
            "please ", "will you ", "would you "
        ]

        for prefix in prefixesToRemove {
            if content.lowercased().hasPrefix(prefix) {
                content = String(content.dropFirst(prefix.count))
                break
            }
        }

        // Capitalize first letter
        content = content.prefix(1).uppercased() + content.dropFirst()

        // Truncate if too long
        if content.count > 100 {
            content = String(content.prefix(97)) + "..."
        }

        guard !content.isEmpty else { return nil }

        return ExtractedTask(
            content: content,
            source: .iMessage,
            sourceId: guid,
            extractedAt: Date(),
            confidence: confidence,
            suggestedSphere: nil,
            suggestedPriority: nil,
            context: "From \(formatSender(sender)) \(formatDate(date))"
        )
    }

    // MARK: - Helpers

    /// Converts Swift Date to Mac Absolute Time (nanoseconds since 2001-01-01)
    private func macAbsoluteTime(from date: Date) -> Double {
        // iMessage stores dates as nanoseconds since 2001-01-01
        return date.timeIntervalSinceReferenceDate * 1_000_000_000
    }

    /// Converts Mac Absolute Time to Swift Date
    private func date(fromMacAbsoluteTime time: Double) -> Date {
        // iMessage dates are nanoseconds since 2001-01-01
        return Date(timeIntervalSinceReferenceDate: time / 1_000_000_000)
    }

    private func formatSender(_ sender: String) -> String {
        // Try to extract just the phone number or email
        if sender.contains("@") {
            // Email - show first part
            return sender.components(separatedBy: "@").first ?? sender
        } else if sender.hasPrefix("+") {
            // Phone number - show last 4 digits
            return "***\(sender.suffix(4))"
        } else {
            return sender
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
