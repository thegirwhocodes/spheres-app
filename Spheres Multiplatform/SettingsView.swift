//
//  SettingsView.swift
//  Spheres - Smart Life Manager
//
//  Settings, preferences, and configuration views.
//

import SwiftUI
import SwiftData
import AppKit

// MARK: - Google Account Settings Section

struct GoogleAccountSettingsSection: View {
    @StateObject private var googleAuth = GoogleAuthService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GOOGLE ACCOUNT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(SpheresTheme.textTertiary)
                .tracking(1)

            VStack(alignment: .leading, spacing: 12) {
                if googleAuth.isSignedIn {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.green)
                            if let email = googleAuth.userEmail {
                                Text(email)
                                    .font(.system(size: 12))
                                    .foregroundColor(SpheresTheme.textSecondary)
                            }
                        }
                        Spacer()
                        Button("Disconnect") {
                            googleAuth.signOut()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                    }
                } else {
                    Text("Connect your Google account to scan Gmail for tasks and action items.")
                        .font(.system(size: 13))
                        .foregroundColor(SpheresTheme.textSecondary)

                    Button(action: {
                        Task {
                            try? await googleAuth.signIn()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                            Text(googleAuth.isAuthenticating ? "Connecting..." : "Connect Gmail")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.accent))
                    }
                    .buttonStyle(.plain)
                    .disabled(googleAuth.isAuthenticating)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var aiService = AIService.shared
    @StateObject private var extractor = OpenLoopExtractor.shared
    @State private var showingExportJSON = false
    @State private var showingExportCSV = false
    @State private var showingBackupSuccess = false
    @State private var showingRestorePicker = false
    @State private var showingRestoreConfirm = false
    @State private var restoreURL: URL?
    @State private var apiKey: String = ""
    @State private var geminiKey: String = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("defaultPriority") private var defaultPriority: Int = 3
    @AppStorage("defaultView") private var defaultView: String = "home"
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("showCompletedLoops") private var showCompletedLoops: Bool = true
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = false
    @State private var showRestartAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                Text("Settings")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .padding(.top, 8)

                // AI Configuration
                VStack(alignment: .leading, spacing: 16) {
                    Text("AI CONFIGURATION")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .tracking(1)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Claude API Key")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(SpheresTheme.textPrimary)
                            Spacer()
                            if aiService.hasAPIKey {
                                HStack(spacing: 4) {
                                    Circle().fill(.green).frame(width: 6, height: 6)
                                    Text("Connected").font(.system(size: 11)).foregroundColor(.green)
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            SecureField("sk-ant-...", text: $apiKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(SpheresTheme.background)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(SpheresTheme.border))
                                )

                            Button("Save") {
                                aiService.setAPIKey(apiKey)
                            }
                            .buttonStyle(AccentButtonStyle())
                            .disabled(apiKey.isEmpty)
                        }

                        Text("Get your key at console.anthropic.com")
                            .font(.system(size: 11))
                            .foregroundColor(SpheresTheme.textTertiary)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
                }

                // Smart Setup
                VStack(alignment: .leading, spacing: 16) {
                    Text("SMART SETUP")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .tracking(1)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Re-run the AI-powered setup to scan your Mac and create or update your spheres.")
                            .font(.system(size: 13))
                            .foregroundColor(SpheresTheme.textSecondary)

                        Button(action: {
                            SmartSetupService.shared.resetForRerun()
                            hasCompletedOnboarding = false
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Re-run Smart Setup")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.accent))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
                }

                // Google Account
                GoogleAccountSettingsSection()

                // Open Loop Sources (Email, Messages, Recordings)
                VStack(alignment: .leading, spacing: 16) {
                    Text("OPEN LOOP SOURCES")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .tracking(1)

                    VStack(alignment: .leading, spacing: 16) {
                        // Gemini API Key (Cheaper option)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Gemini API Key (Recommended)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(SpheresTheme.textPrimary)
                                Spacer()
                                if extractor.hasAIKey {
                                    HStack(spacing: 4) {
                                        Circle().fill(.green).frame(width: 6, height: 6)
                                        Text("Connected").font(.system(size: 11)).foregroundColor(.green)
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                SecureField("AIzaSy...", text: $geminiKey)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(SpheresTheme.background)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(SpheresTheme.border))
                                    )

                                Button("Save") {
                                    extractor.setGeminiKey(geminiKey)
                                }
                                .buttonStyle(AccentButtonStyle())
                                .disabled(geminiKey.isEmpty)
                            }

                            Text("Get free API key at ai.google.dev (cheaper than Claude)")
                                .font(.system(size: 11))
                                .foregroundColor(SpheresTheme.textTertiary)
                        }

                        Divider().background(SpheresTheme.border)

                        // Message History Days
                        HStack {
                            Text("Message History (Days)")
                                .font(.system(size: 13))
                                .foregroundColor(SpheresTheme.textPrimary)
                            Spacer()
                            Picker("", selection: $extractor.messageHistoryDays) {
                                Text("1 day").tag(1)
                                Text("3 days").tag(3)
                                Text("7 days").tag(7)
                                Text("14 days").tag(14)
                            }
                            .frame(width: 120)
                        }

                        Divider().background(SpheresTheme.border)

                        // Source Toggles
                        Toggle("Process Gmail Emails", isOn: $extractor.emailProcessingEnabled)
                            .foregroundColor(SpheresTheme.textPrimary)
                        Toggle("Process iMessages", isOn: $extractor.imessageProcessingEnabled)
                            .foregroundColor(SpheresTheme.textPrimary)
                        Toggle("Process WhatsApp (Beta)", isOn: $extractor.whatsappProcessingEnabled)
                            .foregroundColor(SpheresTheme.textPrimary)
                        Toggle("Process Class Recordings", isOn: $extractor.recordingProcessingEnabled)
                            .foregroundColor(SpheresTheme.textPrimary)

                        // Process Now Button
                        Button("Process All Sources Now") {
                            Task {
                                await extractor.processAllSources(modelContext: modelContext)
                            }
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(!extractor.hasAIKey || extractor.isProcessing)

                        if extractor.isProcessing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Processing...")
                                    .font(.system(size: 12))
                                    .foregroundColor(SpheresTheme.textSecondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
                }

                // Energy Profile
                EnergyProfileSettingsSection()

                // Personalization
                PersonalizationSettingsSection()

                // Preferences
                VStack(alignment: .leading, spacing: 16) {
                    Text("PREFERENCES")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .tracking(1)

                    VStack(spacing: 12) {
                        // Default Priority
                        HStack {
                            Text("Default Priority")
                                .font(.system(size: 13))
                                .foregroundColor(SpheresTheme.textPrimary)
                            Spacer()
                            Picker("", selection: $defaultPriority) {
                                Text("1 (Highest)").tag(1)
                                Text("2").tag(2)
                                Text("3 (Medium)").tag(3)
                                Text("4").tag(4)
                                Text("5 (Lowest)").tag(5)
                            }
                            .frame(width: 140)
                        }

                        Divider().background(SpheresTheme.border)

                        // Default View
                        HStack {
                            Text("Open App To")
                                .font(.system(size: 13))
                                .foregroundColor(SpheresTheme.textPrimary)
                            Spacer()
                            Picker("", selection: $defaultView) {
                                Text("Home").tag("home")
                                Text("Spheres").tag("spheres")
                                Text("Schedule").tag("schedule")
                                Text("Inbox").tag("inbox")
                            }
                            .frame(width: 140)
                        }

                        Divider().background(SpheresTheme.border)

                        // Notifications Toggle
                        Toggle(isOn: $notificationsEnabled) {
                            Text("Enable Notifications")
                                .font(.system(size: 13))
                                .foregroundColor(SpheresTheme.textPrimary)
                        }
                        .toggleStyle(.switch)

                        Divider().background(SpheresTheme.border)

                        // Show Completed Loops
                        Toggle(isOn: $showCompletedLoops) {
                            Text("Show Completed Loops")
                                .font(.system(size: 13))
                                .foregroundColor(SpheresTheme.textPrimary)
                        }
                        .toggleStyle(.switch)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
                }

                // iCloud Sync
                VStack(alignment: .leading, spacing: 16) {
                    Text("SYNC")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .tracking(1)

                    SyncSettingsCard(
                        iCloudSyncEnabled: $iCloudSyncEnabled,
                        showRestartAlert: $showRestartAlert
                    )
                }

                // Privacy Dashboard
                PrivacyDashboard()

                // Export
                VStack(alignment: .leading, spacing: 16) {
                    Text("EXPORT DATA")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .tracking(1)

                    HStack(spacing: 12) {
                        Button(action: { exportJSON() }) {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 24))
                                Text("Export JSON")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(SpheresTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
                        }
                        .buttonStyle(.plain)

                        Button(action: { exportCSV() }) {
                            VStack(spacing: 8) {
                                Image(systemName: "tablecells")
                                    .font(.system(size: 24))
                                Text("Export CSV")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(SpheresTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Backup & Restore
                VStack(alignment: .leading, spacing: 16) {
                    Text("BACKUP & RESTORE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .tracking(1)

                    HStack(spacing: 12) {
                        Button(action: { createBackup() }) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.up.doc")
                                    .font(.system(size: 24))
                                Text("Create Backup")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(SpheresTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
                        }
                        .buttonStyle(.plain)

                        Button(action: { showingRestorePicker = true }) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.doc")
                                    .font(.system(size: 24))
                                Text("Restore Backup")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(SpheresTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
                        }
                        .buttonStyle(.plain)
                    }

                    if showingBackupSuccess {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Backup saved to Documents folder")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                    }
                }

                // Keyboard Shortcuts
                VStack(alignment: .leading, spacing: 16) {
                    Text("KEYBOARD SHORTCUTS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .tracking(1)

                    VStack(spacing: 8) {
                        ShortcutRow(keys: "Cmd + N", action: "Quick Capture")
                        ShortcutRow(keys: "Cmd + 1", action: "Home")
                        ShortcutRow(keys: "Cmd + 2", action: "Spheres")
                        ShortcutRow(keys: "Cmd + 3", action: "Schedule")
                        ShortcutRow(keys: "Cmd + 4", action: "Inbox")
                        ShortcutRow(keys: "Cmd + 5", action: "Mind")
                        ShortcutRow(keys: "Cmd + ,", action: "Settings")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
                }

                // About
                VStack(alignment: .leading, spacing: 16) {
                    Text("ABOUT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .tracking(1)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Spheres - Smart Life Manager")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)
                        Text("Version 1.0")
                            .font(.system(size: 12))
                            .foregroundColor(SpheresTheme.textSecondary)

                        HStack(spacing: 12) {
                            Button("Show Onboarding") {
                                hasCompletedOnboarding = false
                            }
                            .buttonStyle(GhostButtonStyle())

                            Button("Reset & Retake Quiz") {
                                DataManager.shared.clearAllDataForOnboarding(modelContext: modelContext)
                                hasCompletedOnboarding = false
                            }
                            .buttonStyle(GhostButtonStyle())

                            Button("Test AI Popup") {
                                NotificationCenter.default.post(name: .showProactivePopup, object: nil)
                            }
                            .buttonStyle(GhostButtonStyle())
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
                }

                Spacer()
            }
            .padding(32)
        }
        .onAppear {
            apiKey = aiService.getAPIKey()
        }
        .fileImporter(isPresented: $showingRestorePicker, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                restoreURL = url
                showingRestoreConfirm = true
            }
        }
        .alert("Restore Backup?", isPresented: $showingRestoreConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                if let url = restoreURL {
                    _ = DataManager.shared.restoreFromBackup(url: url, modelContext: modelContext)
                }
            }
        } message: {
            Text("This will replace all current data with the backup. This cannot be undone.")
        }
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("OK") {}
        } message: {
            Text("Please restart Spheres for the sync changes to take effect.")
        }
    }

    private func exportJSON() {
        guard let data = DataManager.shared.exportToJSON(modelContext: modelContext) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Spheres_Export.json"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func exportCSV() {
        guard let csv = DataManager.shared.exportToCSV(modelContext: modelContext) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func createBackup() {
        if let _ = DataManager.shared.createBackup(modelContext: modelContext) {
            showingBackupSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showingBackupSuccess = false
            }
        }
    }
}

struct ShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack {
            Text(action)
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.textPrimary)
            Spacer()
            Text(keys)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(SpheresTheme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(SpheresTheme.background))
        }
    }
}
