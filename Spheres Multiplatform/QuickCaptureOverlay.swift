//
//  QuickCaptureOverlay.swift
//  Spheres - Smart Life Manager
//
//  Quick capture overlay with AI-powered task processing.
//  User describes a task naturally, AI assigns sphere, priority, and time estimate.
//

import SwiftUI
import SwiftData
import AppKit
import Speech

// MARK: - Quick Capture Overlay
struct QuickCaptureOverlay: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query private var spheres: [SphereModel]
    @StateObject private var speechService = SpeechService.shared
    @StateObject private var aiService = AIService.shared
    @State private var captureText = ""
    @State private var capturedImage: NSImage?
    @State private var isProcessing = false
    @State private var processingResult: AIService.ProcessedLoop?
    @State private var matchedSphere: SphereModel?
    @State private var showResult = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isProcessing { isPresented = false }
                }

            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(SpheresTheme.accent)
                    Text("Quick Capture")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SpheresTheme.textPrimary)

                    Spacer()

                    if !isProcessing {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14))
                                .foregroundColor(SpheresTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !showResult {
                    // Input mode
                    inputView
                } else {
                    // Result mode - show what AI determined
                    resultView
                }
            }
            .padding(24)
            .frame(width: 480)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(SpheresTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(SpheresTheme.border, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 10)
        }
        .onAppear {
            isFocused = true
        }
        .onChange(of: speechService.transcribedText) { _, newValue in
            if !newValue.isEmpty {
                captureText = newValue
            }
        }
    }

    // MARK: - Input View
    private var inputView: some View {
        VStack(spacing: 16) {
            // Guidance text
            VStack(alignment: .leading, spacing: 4) {
                Text("Describe your task naturally")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)
                Text("Include details like urgency, time needed, and which area of life it belongs to — AI will sort the rest.")
                    .font(.system(size: 11))
                    .foregroundColor(SpheresTheme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextEditor(text: $captureText)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .frame(height: 100)
                .padding(12)
                .background(
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SpheresTheme.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(SpheresTheme.border, lineWidth: 1)
                            )
                        if captureText.isEmpty {
                            Text("e.g., \"Call dentist tomorrow — urgent, ~15 min\" or \"Start reading that leadership book this weekend, low priority\"")
                                .font(.system(size: 13))
                                .foregroundColor(SpheresTheme.textTertiary.opacity(0.6))
                                .padding(.top, 20)
                                .padding(.leading, 16)
                                .allowsHitTesting(false)
                        }
                    }
                )

            // Captured image preview
            if let image = capturedImage {
                HStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 60)
                        .cornerRadius(8)

                    Button(action: { capturedImage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(SpheresTheme.textTertiary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }

            // Error message
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 11))
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                // Microphone button
                Button(action: { toggleRecording() }) {
                    HStack(spacing: 6) {
                        Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 16))
                        if speechService.isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .foregroundColor(speechService.isRecording ? .red : SpheresTheme.textSecondary)
                }
                .buttonStyle(IconButtonStyle())
                .help("Voice to text")

                // Screenshot button
                Button(action: { captureScreenshot() }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(IconButtonStyle())
                .help("Capture screenshot")

                Spacer()

                Button("Cancel") {
                    speechService.stopRecording()
                    isPresented = false
                }
                .buttonStyle(GhostButtonStyle())

                Button {
                    Task { await processWithAI() }
                } label: {
                    HStack(spacing: 6) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                        }
                        Text(isProcessing ? "Processing..." : "Capture")
                    }
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            }
        }
    }

    // MARK: - Result View (AI processed)
    private var resultView: some View {
        VStack(spacing: 16) {
            if let result = processingResult {
                // Task content
                VStack(alignment: .leading, spacing: 6) {
                    Text("Task")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(SpheresTheme.textTertiary)
                    Text(result.content)
                        .font(.system(size: 14))
                        .foregroundColor(SpheresTheme.textPrimary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.background))
                }

                HStack(spacing: 20) {
                    // Sphere
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sphere")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(SpheresTheme.textTertiary)
                        HStack(spacing: 6) {
                            if let sphere = matchedSphere {
                                Circle()
                                    .fill(sphere.color)
                                    .frame(width: 10, height: 10)
                                Text(sphere.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(SpheresTheme.textPrimary)
                            } else {
                                Image(systemName: "tray")
                                    .font(.system(size: 11))
                                    .foregroundColor(SpheresTheme.textTertiary)
                                Text("Inbox")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(SpheresTheme.textSecondary)
                            }
                        }
                    }

                    // Priority
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Priority")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(SpheresTheme.textTertiary)
                        HStack(spacing: 4) {
                            Text("\(result.priority)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(priorityColor(result.priority))
                            Text(priorityLabel(result.priority))
                                .font(.system(size: 12))
                                .foregroundColor(SpheresTheme.textSecondary)
                        }
                    }

                    // Time estimate
                    if let minutes = result.estimatedMinutes {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estimate")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(SpheresTheme.textTertiary)
                            Text("\(minutes) min")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(SpheresTheme.textPrimary)
                        }
                    }

                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(SpheresTheme.background.opacity(0.5)))
            }

            HStack(spacing: 12) {
                Button("Back") {
                    showResult = false
                    processingResult = nil
                    matchedSphere = nil
                }
                .buttonStyle(GhostButtonStyle())

                Spacer()

                Button {
                    createLoopFromResult()
                    isPresented = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                        Text(matchedSphere != nil ? "Add to \(matchedSphere!.name)" : "Save to Inbox")
                    }
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
    }

    // MARK: - AI Processing
    private func processWithAI() async {
        speechService.stopRecording()
        errorMessage = nil
        isProcessing = true

        guard aiService.hasAPIKey else {
            // No API key — fall back to inbox
            isProcessing = false
            saveToInbox()
            isPresented = false
            return
        }

        let result = await aiService.processOpenLoop(captureText, spheres: spheres)

        isProcessing = false

        if let result = result {
            processingResult = result
            // Match sphere by name (case-insensitive)
            matchedSphere = spheres.first { $0.name.lowercased() == result.sphereName.lowercased() }
            showResult = true
        } else {
            // AI failed — fall back to inbox
            errorMessage = "AI couldn't process this — saving to inbox instead."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                saveToInbox()
                isPresented = false
            }
        }
    }

    // MARK: - Create Loop from AI Result
    private func createLoopFromResult() {
        guard let result = processingResult else { return }

        if let sphere = matchedSphere {
            // Create loop directly in the matched sphere
            let _ = DataManager.shared.createLoop(
                content: result.content,
                sphere: sphere,
                importance: result.priority,
                progress: 0.0,
                estimatedMinutes: result.estimatedMinutes,
                modelContext: modelContext
            )
        } else {
            // No matching sphere — save to inbox
            let _ = DataManager.shared.createInboxItem(content: result.content, modelContext: modelContext)
        }

        // Save image if captured
        if let image = capturedImage {
            saveImageForLoop(image: image, itemId: UUID())
        }
    }

    // MARK: - Fallback: Save to Inbox
    private func saveToInbox() {
        speechService.stopRecording()
        let item = DataManager.shared.createInboxItem(content: captureText, modelContext: modelContext)
        if let image = capturedImage {
            saveImageForLoop(image: image, itemId: item.id)
        }
    }

    // MARK: - Helpers
    private func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            speechService.startRecording()
            isFocused = false
        }
    }

    private func captureScreenshot() {
        isPresented = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c"]

            task.terminationHandler = { _ in
                DispatchQueue.main.async {
                    if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                        self.capturedImage = image
                    }
                    self.isPresented = true
                }
            }

            do {
                try task.run()
            } catch {
                print("Screenshot failed: \(error)")
                self.isPresented = true
            }
        }
    }

    private func saveImageForLoop(image: NSImage, itemId: UUID) {
        guard let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        let spheresDir = appSupport.appendingPathComponent("Spheres/Attachments", isDirectory: true)
        try? fileManager.createDirectory(at: spheresDir, withIntermediateDirectories: true)

        let filePath = spheresDir.appendingPathComponent("\(itemId.uuidString).png")
        try? pngData.write(to: filePath)
    }

    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .blue
        default: return SpheresTheme.textTertiary
        }
    }

    private func priorityLabel(_ priority: Int) -> String {
        switch priority {
        case 1: return "Critical"
        case 2: return "High"
        case 3: return "Medium"
        case 4: return "Low"
        case 5: return "Someday"
        default: return ""
        }
    }
}
