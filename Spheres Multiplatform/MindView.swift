//
//  MindView.swift
//  Spheres - Smart Life Manager
//
//  AI chat companion view.
//

import SwiftUI
import SwiftData

// MARK: - Mind View
struct MindView: View {
    @Query(sort: \OpenLoopModel.createdDate) private var allLoops: [OpenLoopModel]
    @Query(sort: \SphereModel.priorityRank) private var spheres: [SphereModel]
    @StateObject private var aiService = AIService.shared
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isProcessing = false
    @State private var showingSettings = false

    private var chatContext: ChatContext {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let completed = allLoops.filter { $0.isCompleted && ($0.completedDate ?? $0.createdDate) > weekAgo }.count

        return ChatContext(
            sphereCount: spheres.count,
            openLoopCount: allLoops.filter { !$0.isCompleted }.count,
            completedThisWeek: completed,
            topSpheres: Array(spheres.prefix(3).map { $0.name })
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mind")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(SpheresTheme.textPrimary)

                    HStack(spacing: 6) {
                        Text("Your AI companion")
                            .font(.system(size: 14))
                            .foregroundColor(SpheresTheme.textSecondary)

                        if aiService.hasAPIKey {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                Spacer()

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16))
                        .foregroundColor(SpheresTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .padding(.bottom, 0)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        if messages.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 48))
                                    .foregroundColor(SpheresTheme.accent.opacity(0.5))

                                if aiService.hasAPIKey {
                                    Text("Ask me anything about your life spheres, tasks, or goals.")
                                        .font(.system(size: 14))
                                        .foregroundColor(SpheresTheme.textSecondary)
                                        .multilineTextAlignment(.center)

                                    VStack(spacing: 8) {
                                        QuickPromptButton(text: "What should I focus on today?") {
                                            sendMessage("What should I focus on today?")
                                        }
                                        QuickPromptButton(text: "How am I doing on my goals?") {
                                            sendMessage("How am I doing on my goals?")
                                        }
                                        QuickPromptButton(text: "Help me prioritize my tasks") {
                                            sendMessage("Help me prioritize my tasks")
                                        }
                                    }
                                } else {
                                    Text("Add your Claude API key in settings to enable AI features.")
                                        .font(.system(size: 14))
                                        .foregroundColor(SpheresTheme.textSecondary)
                                        .multilineTextAlignment(.center)

                                    Button("Open Settings") {
                                        showingSettings = true
                                    }
                                    .buttonStyle(AccentButtonStyle())
                                }
                            }
                            .padding(.vertical, 60)
                        }

                        ForEach(messages) { message in
                            ChatBubble(message: message.content, isUser: message.isUser)
                                .id(message.id)
                        }

                        if isProcessing {
                            HStack {
                                HStack(alignment: .top, spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(SpheresTheme.accent.opacity(0.2))
                                            .frame(width: 32, height: 32)

                                        ProgressView()
                                            .scaleEffect(0.6)
                                    }

                                    Text("Thinking...")
                                        .font(.system(size: 14))
                                        .foregroundColor(SpheresTheme.textTertiary)
                                        .padding(16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(SpheresTheme.surface)
                                        )
                                }
                                Spacer()
                            }
                            .id("processing")
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }

            HStack(spacing: 12) {
                TextField("Ask me anything about your life...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SpheresTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(SpheresTheme.border, lineWidth: 1)
                            )
                    )
                    .onSubmit {
                        if !inputText.isEmpty && !isProcessing {
                            sendMessage(inputText)
                        }
                    }

                Button(action: { sendMessage(inputText) }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.isEmpty || isProcessing ? SpheresTheme.textTertiary : SpheresTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isProcessing)
            }
            .padding(32)
            .padding(.top, 0)
        }
        .sheet(isPresented: $showingSettings) {
            AISettingsSheet(isPresented: $showingSettings)
        }
    }

    private func sendMessage(_ text: String) {
        let userMessage = ChatMessage(content: text, isUser: true, timestamp: Date())
        messages.append(userMessage)
        inputText = ""
        isProcessing = true

        Task {
            let response = await aiService.chat(message: text, context: chatContext)
            await MainActor.run {
                let aiMessage = ChatMessage(content: response, isUser: false, timestamp: Date())
                messages.append(aiMessage)
                isProcessing = false
            }
        }
    }
}

// Quick prompt button
struct QuickPromptButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(SpheresTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(SpheresTheme.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// AI Settings Sheet
struct AISettingsSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var aiService = AIService.shared
    @State private var apiKey: String = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("AI Settings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Claude API Key")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                SecureField("sk-ant-...", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(SpheresTheme.background)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpheresTheme.border))
                    )

                Text("Get your API key from console.anthropic.com")
                    .font(.system(size: 11))
                    .foregroundColor(SpheresTheme.textTertiary)

                if aiService.hasAPIKey {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("API key configured")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                if aiService.hasAPIKey {
                    Button("Remove Key") {
                        aiService.setAPIKey("")
                        apiKey = ""
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                Spacer()

                Button("Cancel") { isPresented = false }
                    .buttonStyle(GhostButtonStyle())

                Button("Save") {
                    aiService.setAPIKey(apiKey)
                    isPresented = false
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(apiKey.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 300)
        .background(SpheresTheme.surface)
        .onAppear {
            apiKey = aiService.getAPIKey()
        }
    }
}

struct ChatBubble: View {
    let message: String
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer() }

            HStack(alignment: .top, spacing: 12) {
                if !isUser {
                    ZStack {
                        Circle()
                            .fill(SpheresTheme.accent.opacity(0.2))
                            .frame(width: 32, height: 32)

                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14))
                            .foregroundColor(SpheresTheme.accent)
                    }
                }

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isUser ? SpheresTheme.accent.opacity(0.2) : SpheresTheme.surface)
                    )

                if isUser {
                    ZStack {
                        Circle()
                            .fill(SpheresTheme.surfaceHover)
                            .frame(width: 32, height: 32)

                        Text("N")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)
                    }
                }
            }

            if !isUser { Spacer() }
        }
    }
}
