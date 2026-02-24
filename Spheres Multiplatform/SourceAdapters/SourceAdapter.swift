//
//  SourceAdapter.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Protocol for extracting tasks from various data sources
//

import Foundation

// MARK: - Extracted Task

/// A task candidate extracted from a source (not yet added to Spheres)
struct ExtractedTask: Identifiable {
    let id = UUID()
    let content: String
    let source: TaskSource
    let sourceId: String          // Original ID in the source app
    let extractedAt: Date
    let confidence: Double        // 0.0 - 1.0, how confident we are this is a real task
    let suggestedSphere: String?  // AI-suggested sphere name
    let suggestedPriority: Int?   // 1-5
    let context: String?          // Original context (subject, note title, etc.)

    /// Whether this should be auto-added (confidence >= 0.9)
    var shouldAutoAdd: Bool {
        confidence >= 0.9
    }

    /// Whether this should be shown as a suggestion (confidence >= 0.7)
    var shouldSuggest: Bool {
        confidence >= 0.7
    }
}

// MARK: - Task Source

enum TaskSource: String, Codable {
    case reminders = "Reminders"
    case appleMail = "Apple Mail"
    case notes = "Notes"
    case voiceMemos = "Voice Memos"
    case iMessage = "iMessage"
    case calendar = "Calendar"
    case manual = "Manual"

    var icon: String {
        switch self {
        case .reminders: return "checkmark.circle.fill"
        case .appleMail: return "envelope.fill"
        case .notes: return "note.text"
        case .voiceMemos: return "waveform"
        case .iMessage: return "message.fill"
        case .calendar: return "calendar"
        case .manual: return "keyboard"
        }
    }

    var color: String {
        switch self {
        case .reminders: return "orange"
        case .appleMail: return "blue"
        case .notes: return "yellow"
        case .voiceMemos: return "red"
        case .iMessage: return "green"
        case .calendar: return "teal"
        case .manual: return "purple"
        }
    }

    var requiresPermission: Bool {
        switch self {
        case .reminders: return true
        case .appleMail: return true  // Automation permission
        case .notes: return true      // Automation permission
        case .voiceMemos: return true // File access
        case .iMessage: return true   // Full Disk Access (App Store blocked)
        case .calendar: return true   // EventKit permission
        case .manual: return false
        }
    }
}

// MARK: - Source Adapter Protocol

/// Protocol for adapters that extract tasks from various sources
protocol SourceAdapter {
    /// The source this adapter handles
    var source: TaskSource { get }

    /// Check if the adapter has necessary permissions
    func checkPermissions() async -> Bool

    /// Request permissions if needed
    func requestPermissions() async -> Bool

    /// Extract tasks from the source
    /// - Parameters:
    ///   - since: Only extract items newer than this date
    ///   - limit: Maximum number of items to extract
    /// - Returns: Array of extracted task candidates
    func extractTasks(since: Date?, limit: Int?) async throws -> [ExtractedTask]

    /// Mark a source item as processed (so we don't extract it again)
    func markAsProcessed(sourceId: String) async
}

// MARK: - Source Adapter Errors

enum SourceAdapterError: Error, LocalizedError {
    case permissionDenied
    case sourceNotAvailable(String)
    case parsingFailed(String)
    case timeout
    case scriptExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission denied to access this source"
        case .sourceNotAvailable(let detail):
            return "This source is not available: \(detail)"
        case .parsingFailed(let detail):
            return "Failed to parse source data: \(detail)"
        case .timeout:
            return "Request timed out"
        case .scriptExecutionFailed(let detail):
            return "Script execution failed: \(detail)"
        }
    }
}

// MARK: - Source Adapter Manager

/// Manages all source adapters and coordinates extraction
@MainActor
class SourceAdapterManager: ObservableObject {
    static let shared = SourceAdapterManager()

    @Published var isExtracting = false
    @Published var lastExtractionDate: Date?
    @Published var pendingTasks: [ExtractedTask] = []

    private var adapters: [TaskSource: any SourceAdapter] = [:]
    private var processedIds: Set<String> = []

    private init() {
        // Load processed IDs from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "processedSourceIds"),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            processedIds = ids
        }

        // Register adapters
        registerAdapter(RemindersAdapter())
        registerAdapter(AppleMailAdapter())
        registerAdapter(NotesAdapter())
        registerAdapter(VoiceMemosAdapter())
        registerAdapter(IMessageAdapter())  // Requires Full Disk Access - only works with direct distribution
    }

    func registerAdapter(_ adapter: any SourceAdapter) {
        adapters[adapter.source] = adapter
    }

    /// Extract tasks from all enabled sources
    func extractFromAllSources(since: Date? = nil) async {
        isExtracting = true
        defer { isExtracting = false }

        var allTasks: [ExtractedTask] = []

        for (source, adapter) in adapters {
            // Check if source is enabled
            guard isSourceEnabled(source) else { continue }

            // Check permissions
            guard await adapter.checkPermissions() else {
                print("DEBUG: Skipping \(source.rawValue) - no permissions")
                continue
            }

            do {
                let tasks = try await adapter.extractTasks(since: since, limit: 50)

                // Filter out already-processed tasks
                let newTasks = tasks.filter { !processedIds.contains($0.sourceId) }
                allTasks.append(contentsOf: newTasks)

            } catch {
                print("DEBUG: Error extracting from \(source.rawValue): \(error)")
            }
        }

        // Sort by confidence (highest first)
        pendingTasks = allTasks.sorted { $0.confidence > $1.confidence }
        lastExtractionDate = Date()
    }

    /// Accept a task and add it to Spheres inbox
    func acceptTask(_ task: ExtractedTask) {
        processedIds.insert(task.sourceId)
        saveProcessedIds()
        pendingTasks.removeAll { $0.id == task.id }
    }

    /// Dismiss a task (mark as processed but don't add)
    func dismissTask(_ task: ExtractedTask) {
        processedIds.insert(task.sourceId)
        saveProcessedIds()
        pendingTasks.removeAll { $0.id == task.id }
    }

    private func isSourceEnabled(_ source: TaskSource) -> Bool {
        switch source {
        case .reminders:
            return UserDefaults.standard.bool(forKey: "permission.reminders")
        case .appleMail:
            return UserDefaults.standard.bool(forKey: "permission.gmail")
        case .notes:
            return UserDefaults.standard.bool(forKey: "permission.notes")
        case .voiceMemos:
            return UserDefaults.standard.bool(forKey: "permission.voiceMemos")
        case .iMessage:
            return UserDefaults.standard.bool(forKey: "permission.imessage")
        case .calendar:
            return UserDefaults.standard.bool(forKey: "permission.calendar")
        case .manual:
            return true
        }
    }

    private func saveProcessedIds() {
        // Keep only last 1000 IDs to prevent unbounded growth
        if processedIds.count > 1000 {
            processedIds = Set(processedIds.suffix(1000))
        }

        if let data = try? JSONEncoder().encode(processedIds) {
            UserDefaults.standard.set(data, forKey: "processedSourceIds")
        }
    }
}
