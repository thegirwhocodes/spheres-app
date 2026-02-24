//
//  PrivacyDashboard.swift
//  Spheres - Smart Life Manager
//
//  At-a-glance privacy status dashboard
//

import SwiftUI

// MARK: - Privacy Dashboard
struct PrivacyDashboard: View {
    @StateObject private var settings = AppPrivacySettings()
    @StateObject private var cloudKit = CloudKitService.shared
    @State private var showingDetailSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy Status")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SpheresTheme.textPrimary)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(privacyHealthColor)
                            .frame(width: 8, height: 8)
                        
                        Text(privacyHealthText)
                            .font(.system(size: 12))
                            .foregroundColor(SpheresTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                Button(action: { showingDetailSheet = true }) {
                    HStack(spacing: 4) {
                        Text("Manage")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(SpheresTheme.accent)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Quick status grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // iCloud Status
                StatusPill(
                    icon: "icloud.fill",
                    title: "iCloud",
                    status: cloudKit.isSignedIn ? .active("Signed In") : .needsAction("Sign In"),
                    color: .blue
                )
                
                // AI Status
                StatusPill(
                    icon: "sparkles",
                    title: "AI",
                    status: settings.aiProcessingEnabled ? .active("On") : .inactive("Off"),
                    color: SpheresTheme.accent
                )
                
                // Connected Apps Count
                let connectedCount = [settings.iMessageEnabled, settings.gmailEnabled, settings.calendarEnabled]
                    .filter { $0 }.count
                StatusPill(
                    icon: "app.connected.to.app.below.fill",
                    title: "Apps",
                    status: connectedCount > 0 ? .active("\(connectedCount) connected") : .inactive("None"),
                    color: .green
                )
                
                // Data Storage
                StatusPill(
                    icon: "externaldrive.fill",
                    title: "Storage",
                    status: settings.iCloudSyncEnabled ? .active("iCloud") : .active("Local"),
                    color: .orange
                )
            }
            
            // Alerts if needed
            if !cloudKit.isSignedIn {
                AlertBanner(
                    icon: "exclamationmark.circle.fill",
                    message: "Sign in to iCloud to sync across devices",
                    action: "Sign In",
                    actionColor: .blue,
                    onAction: { cloudKit.openSystemSettings() }
                )
            }
            
            if settings.gmailEnabled && !settings.aiProcessingEnabled {
                AlertBanner(
                    icon: "info.circle.fill",
                    message: "Enable AI to process Gmail for tasks",
                    action: "Enable",
                    actionColor: SpheresTheme.accent,
                    onAction: { settings.aiProcessingEnabled = true }
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SpheresTheme.surface)
        )
        .sheet(isPresented: $showingDetailSheet) {
            PrivacySettingsView()
        }
        .onAppear {
            cloudKit.checkAccountStatus()
        }
    }
    
    private var privacyHealthColor: Color {
        if cloudKit.isSignedIn && settings.iCloudSyncEnabled {
            return .green
        } else if cloudKit.isSignedIn || settings.hasAnyPermission {
            return .yellow
        } else {
            return SpheresTheme.textMuted
        }
    }
    
    private var privacyHealthText: String {
        if cloudKit.isSignedIn && settings.iCloudSyncEnabled {
            return "All set — syncing enabled"
        } else if cloudKit.isSignedIn {
            return "Signed in — enable sync for backup"
        } else if settings.hasAnyPermission {
            return "Permissions set — sign in for sync"
        } else {
            return "Set up privacy preferences"
        }
    }
}

// MARK: - Status Pill
struct StatusPill: View {
    let icon: String
    let title: String
    let status: Status
    let color: Color
    
    enum Status {
        case active(String)
        case inactive(String)
        case needsAction(String)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SpheresTheme.textTertiary)
                
                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusColor)
            }
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SpheresTheme.background)
        )
    }
    
    private var statusText: String {
        switch status {
        case .active(let text), .inactive(let text), .needsAction(let text):
            return text
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .active: return .green
        case .inactive: return SpheresTheme.textMuted
        case .needsAction: return .orange
        }
    }
}

// MARK: - Alert Banner
struct AlertBanner: View {
    let icon: String
    let message: String
    let action: String
    let actionColor: Color
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(actionColor)
            
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.textSecondary)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onAction) {
                Text(action)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(actionColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(actionColor.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(actionColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(actionColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Enhanced Sign-In Status Indicator
struct EnhancedSignInStatus: View {
    @StateObject private var cloudKit = CloudKitService.shared
    @State private var showingDetailPopover = false
    @State private var isHovering = false
    
    var body: some View {
        Button(action: { showingDetailPopover = true }) {
            HStack(spacing: 6) {
                // Animated status icon
                statusIconView

                // Text status (shows on hover or always for important states)
                if isHovering || !cloudKit.isSignedIn {
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(statusColor)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(backgroundColor)
                    .overlay(
                        Capsule()
                            .stroke(statusColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $showingDetailPopover, arrowEdge: .bottom) {
            SignInDetailPopover()
        }
        .onAppear {
            cloudKit.checkAccountStatus()
        }
    }
    
    @ViewBuilder
    private var statusIconView: some View {
        ZStack {
            if cloudKit.isSignedIn {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var statusText: String {
        if cloudKit.isSignedIn {
            return "Signed In"
        } else {
            return "Sign In"
        }
    }
    
    private var statusColor: Color {
        cloudKit.isSignedIn ? .green : .orange
    }
    
    private var backgroundColor: Color {
        cloudKit.isSignedIn ? Color.green.opacity(0.1) : Color.orange.opacity(0.1)
    }
}

// MARK: - Sign In Detail Popover
struct SignInDetailPopover: View {
    @StateObject private var cloudKit = CloudKitService.shared
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(cloudKit.isSignedIn ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: cloudKit.isSignedIn ? "person.fill.checkmark" : "person.fill.questionmark")
                        .font(.system(size: 16))
                        .foregroundColor(cloudKit.isSignedIn ? .green : .orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Status")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(cloudKit.isSignedIn ? "You're signed in" : "Not signed in")
                        .font(.system(size: 11))
                        .foregroundColor(cloudKit.isSignedIn ? .green : .orange)
                }
                
                Spacer()
            }
            
            Divider()
            
            if cloudKit.isSignedIn {
                // Signed in content
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("Your data is secure")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle(isOn: $iCloudSyncEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync with iCloud")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Access on all your devices")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    if iCloudSyncEnabled {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise.icloud")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text("Sync enabled")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Button(action: { cloudKit.openSystemSettings() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                        Text("Manage in Settings")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                // Not signed in content
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sign in to iCloud to:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        BenefitText(icon: "iphone", text: "Sync with iPhone & iPad")
                        BenefitText(icon: "arrow.clockwise.icloud", text: "Backup your data")
                        BenefitText(icon: "lock.shield", text: "End-to-end encryption")
                    }
                    
                    Button(action: { cloudKit.openSystemSettings() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Open System Settings")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(width: 240)
    }
}

struct BenefitText: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.blue)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        PrivacyDashboard()
            .padding()
        
        EnhancedSignInStatus()
    }
    .background(SpheresTheme.background)
}
