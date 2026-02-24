//
//  QuickCaptureOverlay.swift
//  Spheres - Smart Life Manager
//
//  Quick capture overlay for capturing thoughts, tasks, and screenshots.
//

import SwiftUI
import SwiftData
import AppKit
import Speech

// MARK: - Quick Capture Overlay
struct QuickCaptureOverlay: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultPriority") private var defaultPriority: Int = 3
    @StateObject private var speechService = SpeechService.shared
    @State private var captureText = ""
    @State private var importance = 3
    @State private var capturedImage: NSImage?
    @State private var showingImagePicker = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(SpheresTheme.accent)
                    Text("Quick Capture")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SpheresTheme.textPrimary)

                    Spacer()

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(SpheresTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                TextEditor(text: $captureText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .frame(height: 100)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SpheresTheme.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(SpheresTheme.border, lineWidth: 1)
                            )
                    )

                // Importance Selector
                HStack {
                    Text("Priority")
                        .font(.system(size: 12))
                        .foregroundColor(SpheresTheme.textSecondary)

                    Spacer()

                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { level in
                            Button(action: { importance = level }) {
                                Circle()
                                    .fill(level <= importance ? SpheresTheme.accent : SpheresTheme.border)
                                    .frame(width: 14, height: 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

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

                    Button("Capture") {
                        saveToInbox()
                        isPresented = false
                    }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(captureText.isEmpty)
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
            importance = defaultPriority
        }
        .onChange(of: speechService.transcribedText) { _, newValue in
            if !newValue.isEmpty {
                captureText = newValue
            }
        }
    }

    private func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            speechService.startRecording()
            isFocused = false // Unfocus text editor while recording
        }
    }

    private func captureScreenshot() {
        // Hide the overlay temporarily
        isPresented = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Use screencapture command for interactive selection
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c"] // Interactive, copy to clipboard

            task.terminationHandler = { _ in
                DispatchQueue.main.async {
                    // Get image from clipboard
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

    private func saveToInbox() {
        speechService.stopRecording()

        // Save text to inbox
        let item = DataManager.shared.createInboxItem(content: captureText, modelContext: modelContext)

        // If there's an image, save it
        if let image = capturedImage {
            saveImageForLoop(image: image, itemId: item.id)
        }
    }

    private func saveImageForLoop(image: NSImage, itemId: UUID) {
        // Save to app's documents directory
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
}
