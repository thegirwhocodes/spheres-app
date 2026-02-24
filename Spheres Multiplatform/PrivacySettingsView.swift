//
//  PrivacySettingsView.swift
//  Spheres - Smart Life Manager
//
//  Granular privacy controls with clear status indicators
//

import SwiftUI
import SwiftData

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var settings = AppPrivacySettings()
    @StateObject private var cloudKit = CloudKitService.shared
    @State private var showingDataExport = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPrivacyInfo = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy & Security")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(SpheresTheme.textPrimary)
                    
                    Text("Control what Spheres can access and how your data is used.")
                        .font(.system(size: 14))
                        .foregroundColor(SpheresTheme.textSecondary)
                }
                
                // Connected Accounts Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "CONNECTED ACCOUNTS", icon: "link.circle.fill")
                    
                    VStack(spacing: 12) {
                        ConnectedAccountCard(
                            icon: "message.fill",
                            iconColor: .green,
                            title: "iMessage",
                            status: settings.iMessageEnabled ? .connected : .disconnected,
                            lastSync: settings.iMessageLastSync,
                            isEnabled: $settings.iMessageEnabled
                        )
                        
                        ConnectedAccountCard(
                            icon: "envelope.fill",
                            iconColor: .blue,
                            title: "Gmail",
                            status: settings.gmailEnabled ? .connected : .disconnected,
                            lastSync: settings.gmailLastSync,
                            isEnabled: $settings.gmailEnabled
                        )
                        
                        ConnectedAccountCard(
                            icon: "calendar",
                            iconColor: .red,
                            title: "Calendar",
                            status: settings.calendarEnabled ? .connected : .disconnected,
                            lastSync: settings.calendarLastSync,
                            isEnabled: $settings.calendarEnabled
                        )
                    }
                }
                
                // AI Processing Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "AI PROCESSING", icon: "brain.head.profile")
                    
                    VStack(alignment: .leading, spacing: 12) {
                        AIProcessingCard(isEnabled: $settings.aiProcessingEnabled)
                        
                        if settings.aiProcessingEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("AI processes text to find tasks. Original messages are not stored.")
                                    .font(.system(size: 12))
                                    .foregroundColor(SpheresTheme.textSecondary)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                    }
                }
                
                // iCloud Sync Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "SYNC & BACKUP", icon: "icloud.fill")
                    
                    iCloudSyncDetailCard(
                        isSignedIn: cloudKit.isSignedIn,
                        isSyncEnabled: $settings.iCloudSyncEnabled,
                        lastSync: cloudKit.lastSyncDate
                    )
                }
                
                // Data Management Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "DATA MANAGEMENT", icon: "externaldrive.fill")
                    
                    VStack(spacing: 12) {
                        DataActionButton(
                            icon: "arrow.down.doc",
                            title: "Export My Data",
                            description: "Download all your data as JSON",
                            action: { showingDataExport = true }
                        )
                        
                        DataActionButton(
                            icon: "trash.fill",
                            title: "Delete All Data",
                            description: "Permanently remove all app data",
                            isDestructive: true,
                            action: { showingDeleteConfirmation = true }
                        )
                    }
                }
                
                // Privacy Info
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "ABOUT", icon: "info.circle.fill")
                    
                    Button(action: { showingPrivacyInfo = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Privacy Policy")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(SpheresTheme.textPrimary)
                                
                                Text("Learn how we protect your data")
                                    .font(.system(size: 12))
                                    .foregroundColor(SpheresTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(SpheresTheme.textTertiary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SpheresTheme.surface)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // App version
                HStack {
                    Spacer()
                    Text("Spheres v1.0 • Build 2025.02.15")
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.textTertiary)
                    Spacer()
                }
                .padding(.top, 16)
            }
            .padding(24)
        }
        .background(SpheresTheme.background)
        .sheet(isPresented: $showingDataExport) {
            DataExportSheet()
        }
        .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Delete all SwiftData records (spheres, loops, inbox, profiles)
                DataManager.shared.clearAllDataForOnboarding(modelContext: modelContext)
                // Also clear settings
                settings.deleteAllData()
            }
        } message: {
            Text("This will permanently delete all your spheres, loops, and settings. This action cannot be undone.")
        }
        .onAppear {
            cloudKit.checkAccountStatus()
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.accent)
            
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(SpheresTheme.textTertiary)
                .tracking(1)
        }
    }
}

// MARK: - Connected Account Card
struct ConnectedAccountCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let status: ConnectionStatus
    let lastSync: Date?
    @Binding var isEnabled: Bool
    @State private var isHovering = false
    
    enum ConnectionStatus: Equatable {
        case connected
        case disconnected
        case error(String)

        static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.connected, .connected), (.disconnected, .disconnected):
                return true
            case let (.error(lhsMsg), .error(rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }

        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .disconnected: return "circle"
            case .error: return "exclamationmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .disconnected: return SpheresTheme.textMuted
            case .error: return .red
            }
        }
        
        var text: String {
            switch self {
            case .connected: return "Connected"
            case .disconnected: return "Not connected"
            case .error(let msg): return msg
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SpheresTheme.textPrimary)
                    
                    // Status indicator
                    HStack(spacing: 4) {
                        Image(systemName: status.icon)
                            .font(.system(size: 10))
                        Text(status.text)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(status.color)
                }
                
                if let lastSync = lastSync, status == .connected {
                    Text("Last synced \(formatRelativeDate(lastSync))")
                        .font(.system(size: 12))
                        .foregroundColor(SpheresTheme.textSecondary)
                } else {
                    Text("Enable to find tasks automatically")
                        .font(.system(size: 12))
                        .foregroundColor(SpheresTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SpheresTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEnabled ? SpheresTheme.accent.opacity(0.3) : SpheresTheme.border, lineWidth: 1)
                )
        )
        .onHover { isHovering = $0 }
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - AI Processing Card
struct AIProcessingCard: View {
    @Binding var isEnabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(SpheresTheme.accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(SpheresTheme.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Task Extraction")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SpheresTheme.textPrimary)
                    
                    Text(isEnabled ? "Active — finding tasks in your messages" : "Disabled — manual entry only")
                        .font(.system(size: 12))
                        .foregroundColor(isEnabled ? .green : SpheresTheme.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            if isEnabled {
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    PrivacyFeatureRow(
                        icon: "lock.shield.fill",
                        title: "Encrypted",
                        description: "All data sent over HTTPS/TLS 1.3"
                    )
                    
                    PrivacyFeatureRow(
                        icon: "timer",
                        title: "No Storage",
                        description: "Messages are processed instantly and discarded"
                    )
                    
                    PrivacyFeatureRow(
                        icon: "eye.slash.fill",
                        title: "No Training",
                        description: "Your data is never used to train AI models"
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SpheresTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEnabled ? SpheresTheme.accent.opacity(0.3) : SpheresTheme.border, lineWidth: 1)
                )
        )
    }
}

struct PrivacyFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.accent)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(SpheresTheme.textSecondary)
            }
        }
    }
}

// MARK: - iCloud Sync Detail Card
struct iCloudSyncDetailCard: View {
    let isSignedIn: Bool
    @Binding var isSyncEnabled: Bool
    let lastSync: Date?
    @StateObject private var cloudKit = CloudKitService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSignedIn ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: isSignedIn ? "checkmark" : "person.fill.questionmark")
                        .font(.system(size: 20))
                        .foregroundColor(isSignedIn ? .green : .orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isSignedIn ? "Signed in to iCloud" : "Sign in to iCloud")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SpheresTheme.textPrimary)
                    
                    if isSignedIn {
                        Text("Your data syncs across all your devices")
                            .font(.system(size: 13))
                            .foregroundColor(SpheresTheme.textSecondary)
                    } else {
                        Text("Go to System Settings → Apple ID → iCloud")
                            .font(.system(size: 13))
                            .foregroundColor(SpheresTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                if !isSignedIn {
                    Button(action: { cloudKit.openSystemSettings() }) {
                        Text("Sign In")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if isSignedIn {
                Divider()
                
                // Sync Toggle
                Toggle(isOn: $isSyncEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable iCloud Sync")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)
                        
                        Text("Encrypted end-to-end with your Apple ID")
                            .font(.system(size: 12))
                            .foregroundColor(SpheresTheme.textSecondary)
                    }
                }
                .toggleStyle(.switch)
                
                if isSyncEnabled, let lastSync = lastSync {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        
                        Text("Last synced: \(formatDetailedDate(lastSync))")
                            .font(.system(size: 11))
                            .foregroundColor(SpheresTheme.textSecondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SpheresTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSignedIn ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func formatDetailedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Data Action Button
struct DataActionButton: View {
    let icon: String
    let title: String
    let description: String
    var isDestructive = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isDestructive ? Color.red.opacity(0.15) : SpheresTheme.surface)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isDestructive ? .red : SpheresTheme.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isDestructive ? .red : SpheresTheme.textPrimary)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(SpheresTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(SpheresTheme.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SpheresTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SpheresTheme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Data Export Sheet
struct DataExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportComplete = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            if exportComplete {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Export Complete!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(SpheresTheme.textPrimary)
                    
                    Text("Your data has been saved to your Downloads folder.")
                        .font(.system(size: 14))
                        .foregroundColor(SpheresTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(AccentButtonStyle())
                    .padding(.top, 16)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 48))
                        .foregroundColor(SpheresTheme.accent)
                    
                    Text("Export Your Data")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(SpheresTheme.textPrimary)
                    
                    Text("We'll create a JSON file with all your spheres, loops, and settings. This file can be used to backup or transfer your data.")
                        .font(.system(size: 14))
                        .foregroundColor(SpheresTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ExportInfoRow(text: "Includes all spheres and loops")
                        ExportInfoRow(text: "Does not include connected account credentials")
                        ExportInfoRow(text: "File will be saved to Downloads")
                    }
                    .padding(.vertical, 8)
                    
                    Button(action: { exportData() }) {
                        HStack(spacing: 8) {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isExporting ? "Exporting..." : "Export Data")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 200)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SpheresTheme.accent)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isExporting)
                }
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 400, height: 400)
    }
    
    private func exportData() {
        isExporting = true
        // Simulate export
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isExporting = false
            exportComplete = true
        }
    }
}

struct ExportInfoRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 10))
                .foregroundColor(.green)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(SpheresTheme.textSecondary)
        }
    }
}

// MARK: - App Privacy Settings Model
class AppPrivacySettings: ObservableObject {
    @AppStorage("permission.imessage") var iMessageEnabled = false
    @AppStorage("permission.gmail") var gmailEnabled = false
    @AppStorage("permission.calendar") var calendarEnabled = false
    @AppStorage("permission.aiProcessing") var aiProcessingEnabled = false
    @AppStorage("iCloudSyncEnabled") var iCloudSyncEnabled = false
    
    // Use TimeInterval for Date storage (compatible with older macOS)
    @AppStorage("lastSync.imessage") private var iMessageLastSyncInterval: TimeInterval = 0
    @AppStorage("lastSync.gmail") private var gmailLastSyncInterval: TimeInterval = 0
    @AppStorage("lastSync.calendar") private var calendarLastSyncInterval: TimeInterval = 0
    
    var iMessageLastSync: Date? {
        get { iMessageLastSyncInterval > 0 ? Date(timeIntervalSince1970: iMessageLastSyncInterval) : nil }
        set { iMessageLastSyncInterval = newValue?.timeIntervalSince1970 ?? 0 }
    }
    
    var gmailLastSync: Date? {
        get { gmailLastSyncInterval > 0 ? Date(timeIntervalSince1970: gmailLastSyncInterval) : nil }
        set { gmailLastSyncInterval = newValue?.timeIntervalSince1970 ?? 0 }
    }
    
    var calendarLastSync: Date? {
        get { calendarLastSyncInterval > 0 ? Date(timeIntervalSince1970: calendarLastSyncInterval) : nil }
        set { calendarLastSyncInterval = newValue?.timeIntervalSince1970 ?? 0 }
    }
    
    var hasAnyPermission: Bool {
        iMessageEnabled || gmailEnabled || calendarEnabled
    }
    
    func deleteAllData() {
        // Clear all data
        iMessageEnabled = false
        gmailEnabled = false
        calendarEnabled = false
        aiProcessingEnabled = false
        iCloudSyncEnabled = false
        iMessageLastSyncInterval = 0
        gmailLastSyncInterval = 0
        calendarLastSyncInterval = 0
        
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Note: Actual SwiftData deletion would happen here
    }
}

// MARK: - Preview
#Preview {
    PrivacySettingsView()
}
