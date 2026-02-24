//
//  VoiceMemosAdapter.swift
//  Spheres Multiplatform
//
//  Created by Spheres on 2025.
//  Extracts tasks from Apple Voice Memos via file parsing + SFSpeechRecognizer
//

import Foundation
import Speech
import AVFoundation

class VoiceMemosAdapter: SourceAdapter {
    let source: TaskSource = .voiceMemos

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    // Task detection patterns
    private let taskPatterns = [
        "remind me to",
        "i need to",
        "i have to",
        "don't forget to",
        "make sure to",
        "todo",
        "to do",
        "task",
        "remember to",
        "gotta",
        "should"
    ]

    private let actionVerbs = [
        "buy", "call", "email", "send", "schedule", "book", "order",
        "review", "read", "write", "complete", "finish", "start",
        "fix", "update", "check", "confirm", "prepare", "create",
        "research", "find", "get", "pick up", "submit", "pay",
        "meet", "contact", "follow up"
    ]

    // Voice Memos storage location
    private var voiceMemosDirectory: URL? {
        let groupContainers = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings")

        if FileManager.default.fileExists(atPath: groupContainers.path) {
            return groupContainers
        }

        // Fallback to older location
        let oldLocation = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.voicememos/Recordings")

        if FileManager.default.fileExists(atPath: oldLocation.path) {
            return oldLocation
        }

        return nil
    }

    func checkPermissions() async -> Bool {
        // Check speech recognition permission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        guard speechStatus == .authorized else {
            return false
        }

        // Check if we can access Voice Memos directory
        guard let dir = voiceMemosDirectory else {
            return false
        }

        return FileManager.default.isReadableFile(atPath: dir.path)
    }

    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func extractTasks(since: Date?, limit: Int?) async throws -> [ExtractedTask] {
        guard await checkPermissions() else {
            throw SourceAdapterError.permissionDenied
        }

        guard let directory = voiceMemosDirectory else {
            throw SourceAdapterError.sourceNotAvailable("Voice Memos directory not found")
        }

        // Get .m4a files
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ).filter { $0.pathExtension.lowercased() == "m4a" }

        // Filter by date if specified
        var filteredFiles = files
        if let since = since {
            filteredFiles = files.filter { file in
                let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
                let modDate = attrs?[.modificationDate] as? Date ?? Date.distantPast
                return modDate >= since
            }
        }

        // Limit number of files to process
        let maxFiles = limit ?? 10
        let filesToProcess = Array(filteredFiles.prefix(maxFiles))

        var allTasks: [ExtractedTask] = []

        for file in filesToProcess {
            do {
                let tasks = try await processVoiceMemo(at: file)
                allTasks.append(contentsOf: tasks)
            } catch {
                print("DEBUG: Failed to process voice memo \(file.lastPathComponent): \(error)")
            }
        }

        return allTasks
    }

    func markAsProcessed(sourceId: String) async {
        // Could add to a processed list
        // For now, tracked in SourceAdapterManager
    }

    // MARK: - Voice Memo Processing

    private func processVoiceMemo(at url: URL) async throws -> [ExtractedTask] {
        // First try to extract embedded transcription (tsrp atom)
        if let embeddedTranscript = extractEmbeddedTranscription(from: url) {
            return extractTasksFromTranscript(embeddedTranscript, sourceUrl: url)
        }

        // Fall back to speech recognition
        let transcript = try await transcribeAudio(at: url)
        return extractTasksFromTranscript(transcript, sourceUrl: url)
    }

    /// Extracts embedded transcription from m4a file (tsrp atom)
    /// Voice Memos stores transcriptions in a custom atom
    private func extractEmbeddedTranscription(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        // Look for "tsrp" atom marker in the file
        // This is where Voice Memos stores its transcription
        let tsrpMarker = "tsrp".data(using: .ascii)!

        guard let range = data.range(of: tsrpMarker) else { return nil }

        // The transcription data follows the marker
        // Format: tsrp [4-byte size] [content]
        let startIndex = range.upperBound + 4  // Skip size bytes

        // Find the end - look for next atom or use reasonable limit
        let endIndex = min(startIndex + 10000, data.count)  // Max 10KB

        guard startIndex < data.count else { return nil }

        let transcriptData = data.subdata(in: startIndex..<endIndex)

        // Try to decode as UTF-8
        if let transcript = String(data: transcriptData, encoding: .utf8) {
            // Clean up any binary garbage at the end
            let cleaned = transcript.components(separatedBy: CharacterSet.controlCharacters).joined()
            return cleaned.isEmpty ? nil : cleaned
        }

        return nil
    }

    /// Transcribes audio using SFSpeechRecognizer
    private func transcribeAudio(at url: URL) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SourceAdapterError.scriptExecutionFailed("Speech recognizer not available")
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

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

    // MARK: - Task Extraction

    private func extractTasksFromTranscript(_ transcript: String, sourceUrl: URL) -> [ExtractedTask] {
        var tasks: [ExtractedTask] = []
        let lowercased = transcript.lowercased()

        // Split into sentences
        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?"))

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let sentenceLower = trimmed.lowercased()
            var confidence = 0.0

            // Check for explicit task patterns
            for pattern in taskPatterns {
                if sentenceLower.contains(pattern) {
                    confidence = max(confidence, 0.85)
                    break
                }
            }

            // Check for action verbs at start
            if confidence < 0.8 {
                for verb in actionVerbs {
                    if sentenceLower.hasPrefix(verb) || sentenceLower.hasPrefix("i \(verb)") {
                        confidence = max(confidence, 0.75)
                        break
                    }
                }
            }

            // Skip if not task-like enough
            guard confidence >= 0.7 else { continue }

            // Clean up the task content
            var content = trimmed

            // Remove common prefixes
            let prefixesToRemove = ["remind me to ", "i need to ", "i have to ", "don't forget to ", "make sure to ", "remember to ", "i should ", "i gotta "]
            for prefix in prefixesToRemove {
                if content.lowercased().hasPrefix(prefix) {
                    content = String(content.dropFirst(prefix.count))
                    break
                }
            }

            // Capitalize first letter
            content = content.prefix(1).uppercased() + content.dropFirst()

            guard !content.isEmpty else { continue }

            let fileAttrs = try? FileManager.default.attributesOfItem(atPath: sourceUrl.path)
            let recordingDate = fileAttrs?[.creationDate] as? Date ?? Date()

            tasks.append(ExtractedTask(
                content: content,
                source: .voiceMemos,
                sourceId: sourceUrl.lastPathComponent,
                extractedAt: Date(),
                confidence: confidence,
                suggestedSphere: nil,
                suggestedPriority: nil,
                context: "Voice Memo recorded \(formatDate(recordingDate))"
            ))
        }

        return tasks
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
