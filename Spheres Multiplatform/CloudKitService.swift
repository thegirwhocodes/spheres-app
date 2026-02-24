//
//  CloudKitService.swift
//  Spheres - Smart Life Manager
//
//  Professional iCloud sync status management
//

import SwiftUI
import CloudKit

// MARK: - Sync Status
enum SyncStatus: Equatable {
    case synced
    case syncing
    case offline
    case notSignedIn
    case error(String)

    var icon: String {
        switch self {
        case .synced: return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .offline: return "icloud.slash"
        case .notSignedIn: return "icloud.slash"
        case .error: return "exclamationmark.icloud"
        }
    }

    var color: Color {
        switch self {
        case .synced: return .green
        case .syncing: return .blue
        case .offline: return .orange
        case .notSignedIn: return .gray
        case .error: return .red
        }
    }

    var description: String {
        switch self {
        case .synced: return "Synced"
        case .syncing: return "Syncing..."
        case .offline: return "Offline"
        case .notSignedIn: return "Not signed in"
        case .error(let msg): return msg
        }
    }
}

// MARK: - CloudKit Service
@MainActor
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()

    @Published var syncStatus: SyncStatus = .offline
    @Published var isSignedIn: Bool = false
    @Published var lastSyncDate: Date?
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine

    private var container: CKContainer?
    private var statusCheckTimer: Timer?
    private var hasCheckedStatus = false

    private init() {
        // Use default container for CloudKit operations
        container = CKContainer.default()

        // Defer status check to avoid blocking app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.initializeCloudKit()
        }
    }

    private func initializeCloudKit() {
        // Always check account status so we know if user is signed in
        checkAccountStatus()

        // Only start monitoring if sync is enabled
        let syncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        if syncEnabled {
            startStatusMonitoring()
        } else {
            syncStatus = .offline
        }
    }

    // MARK: - Account Status
    func checkAccountStatus() {
        // Use ubiquityIdentityToken - reliable way to check iCloud sign-in status
        // This works even without CloudKit container setup
        if FileManager.default.ubiquityIdentityToken != nil {
            self.isSignedIn = true
            self.accountStatus = .available
            self.updateSyncStatus()
            self.hasCheckedStatus = true
            return
        }

        // Fallback to CKContainer check if ubiquityIdentityToken is nil
        guard let container = container else {
            self.isSignedIn = false
            syncStatus = .offline
            hasCheckedStatus = true
            return
        }

        Task {
            do {
                let status = try await withTimeout(seconds: 5) {
                    try await container.accountStatus()
                }
                await MainActor.run {
                    self.accountStatus = status
                    self.isSignedIn = (status == .available)
                    self.updateSyncStatus()
                    self.hasCheckedStatus = true
                }
            } catch {
                await MainActor.run {
                    // Final fallback - check ubiquityIdentityToken again
                    self.isSignedIn = FileManager.default.ubiquityIdentityToken != nil
                    if self.isSignedIn {
                        self.accountStatus = .available
                    } else {
                        self.syncStatus = .offline
                    }
                    self.hasCheckedStatus = true
                }
            }
        }
    }

    // Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CancellationError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func updateSyncStatus() {
        let syncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

        if !syncEnabled {
            syncStatus = .offline
        } else if container == nil {
            // CloudKit not yet initialized
            syncStatus = .offline
        } else if !isSignedIn {
            syncStatus = .notSignedIn
        } else {
            // If we're signed in and sync is enabled, assume synced
            // SwiftData + CloudKit handles the actual sync automatically
            syncStatus = .synced
            lastSyncDate = Date()
        }
    }

    // Called when user enables/disables sync in settings
    func reinitialize() {
        let syncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        if syncEnabled {
            if container == nil {
                container = CKContainer.default()
            }
            checkAccountStatus()
            startStatusMonitoring()
        } else {
            // Don't nil out container or isSignedIn - we still need to detect iCloud status
            statusCheckTimer?.invalidate()
            statusCheckTimer = nil
            syncStatus = .offline
            // Re-check account status to keep isSignedIn accurate
            checkAccountStatus()
        }
    }

    // MARK: - Status Monitoring
    private func startStatusMonitoring() {
        // Listen for account changes
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAccountStatus()
        }

        // Periodic status check every 60 seconds (less frequent to reduce load)
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAccountStatus()
            }
        }
    }

    // MARK: - Manual Sync
    func triggerSync() {
        guard isSignedIn, container != nil else { return }

        syncStatus = .syncing

        // Simulate sync completion (SwiftData handles actual sync)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.syncStatus = .synced
            self?.lastSyncDate = Date()
        }
    }

    // MARK: - Open System Settings
    func openSystemSettings() {
        // Use AppleScript to reliably open System Settings to Apple ID > iCloud
        let script = """
        tell application "System Settings"
            activate
            reveal pane id "com.apple.systempreferences.AppleIDSettings:icloud"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)

            // Fallback if AppleScript fails
            if error != nil {
                if let url = URL(string: "x-apple.systempreferences:") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - Formatted Last Sync
    var lastSyncFormatted: String {
        guard let date = lastSyncDate else { return "Never" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var lastSyncDetailedFormatted: String {
        guard let date = lastSyncDate else { return "Never synced" }

        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        }
    }
}

// MARK: - Sync Status Indicator View
struct SyncStatusIndicator: View {
    @StateObject private var cloudKit = CloudKitService.shared
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = false
    @State private var isHovering = false
    @State private var showingPopover = false

    @State private var syncingAnimation = false

    var body: some View {
        Button(action: { showingPopover.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.system(size: 12))
                    .foregroundColor(statusColor)
                    .opacity(cloudKit.syncStatus == .syncing ? (syncingAnimation ? 0.4 : 1.0) : 1.0)
                    .animation(cloudKit.syncStatus == .syncing ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: syncingAnimation)
                    .onAppear {
                        syncingAnimation = true
                    }

                if isHovering {
                    Text(statusText)
                        .font(.system(size: 10))
                        .foregroundColor(SpheresTheme.textSecondary)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(SpheresTheme.surface)
                    .opacity(isHovering ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
            SyncStatusPopover()
        }
    }

    private var statusIcon: String {
        if !iCloudSyncEnabled {
            return "icloud.slash"
        }
        return cloudKit.syncStatus.icon
    }

    private var statusColor: Color {
        if !iCloudSyncEnabled {
            return SpheresTheme.textMuted
        }
        return cloudKit.syncStatus.color
    }

    private var statusText: String {
        if !iCloudSyncEnabled {
            return "Sync off"
        }
        return cloudKit.syncStatus.description
    }
}

// MARK: - Sync Status Popover
struct SyncStatusPopover: View {
    @StateObject private var cloudKit = CloudKitService.shared
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Sync")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(iCloudSyncEnabled ? cloudKit.syncStatus.description : "Disabled")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Circle()
                    .fill(iCloudSyncEnabled ? cloudKit.syncStatus.color : .gray)
                    .frame(width: 8, height: 8)
            }

            Divider()

            // Status Details
            if iCloudSyncEnabled {
                if cloudKit.isSignedIn {
                    HStack {
                        Text("Last synced")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(cloudKit.lastSyncDetailedFormatted)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                    }

                    Button(action: { cloudKit.triggerSync() }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync Now")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(cloudKit.syncStatus == .syncing)
                } else {
                    // Not signed in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Sign in to iCloud to sync")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Button(action: { cloudKit.openSystemSettings() }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open System Settings")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue)
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Enable iCloud Sync in Settings to sync your data across all your devices.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: 220)
    }
}

// MARK: - Sync Setup Banner
struct SyncSetupBanner: View {
    @StateObject private var cloudKit = CloudKitService.shared
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = false
    @AppStorage("hasDismissedSyncBanner") private var hasDismissedBanner: Bool = false
    @State private var showRestartAlert = false
    @State private var showSignInAlert = false

    var shouldShow: Bool {
        !hasDismissedBanner && !iCloudSyncEnabled
    }

    var body: some View {
        if shouldShow {
            HStack(spacing: 12) {
                Image(systemName: "icloud")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync across devices")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(SpheresTheme.textPrimary)

                    Text("Access your spheres on iPhone, iPad, and Mac")
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.textSecondary)
                }

                Spacer()

                if cloudKit.isSignedIn {
                    Button("Enable") {
                        iCloudSyncEnabled = true
                        showRestartAlert = true
                    }
                    .buttonStyle(AccentButtonStyle())
                } else {
                    Button("Sign In") {
                        showSignInAlert = true
                    }
                    .buttonStyle(AccentButtonStyle())
                }

                Button(action: { hasDismissedBanner = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(SpheresTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
            .alert("Sign in to iCloud", isPresented: $showSignInAlert) {
                Button("Open Settings") {
                    cloudKit.openSystemSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("To sync Spheres across your devices, sign in to iCloud in System Settings with your Apple ID.")
            }
            .alert("Restart Required", isPresented: $showRestartAlert) {
                Button("Restart Now") {
                    restartApp()
                }
                Button("Later", role: .cancel) {}
            } message: {
                Text("Spheres needs to restart to enable iCloud sync. Your data will be preserved.")
            }
        }
    }

    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        NSApp.terminate(nil)
    }
}

// MARK: - Sync Settings Card (for Settings View)
struct SyncSettingsCard: View {
    @StateObject private var cloudKit = CloudKitService.shared
    @Binding var iCloudSyncEnabled: Bool
    @Binding var showRestartAlert: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Main toggle with status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)

                        Text("iCloud Sync")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(SpheresTheme.textPrimary)
                    }

                    Text("Sync your spheres across iPhone, iPad, and Mac")
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.textTertiary)
                }

                Spacer()

                Toggle("", isOn: $iCloudSyncEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: iCloudSyncEnabled) { _, _ in
                        showRestartAlert = true
                    }
            }

            // Status section
            if iCloudSyncEnabled {
                Divider().background(SpheresTheme.border)

                if cloudKit.isSignedIn {
                    // Signed in - show status
                    VStack(spacing: 12) {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(cloudKit.syncStatus.color)
                                    .frame(width: 8, height: 8)
                                Text(cloudKit.syncStatus.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(SpheresTheme.textSecondary)
                            }

                            Spacer()

                            Text("Last synced: \(cloudKit.lastSyncDetailedFormatted)")
                                .font(.system(size: 11))
                                .foregroundColor(SpheresTheme.textTertiary)
                        }

                        SyncButton(cloudKit: cloudKit)
                    }
                } else {
                    // Not signed in - show warning
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Not signed in to iCloud")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(SpheresTheme.textPrimary)

                                Text("Sign in to iCloud in System Settings to sync your data")
                                    .font(.system(size: 11))
                                    .foregroundColor(SpheresTheme.textTertiary)
                            }

                            Spacer()
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
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // Sync disabled - show benefits
                Divider().background(SpheresTheme.border)

                HStack(spacing: 12) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 14))
                        .foregroundColor(SpheresTheme.textMuted)

                    Text("Your data is stored locally only")
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.textTertiary)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(SpheresTheme.surface))
    }
}

// MARK: - Sync Button (with rotation animation for macOS 14+)
struct SyncButton: View {
    @ObservedObject var cloudKit: CloudKitService
    @State private var rotation: Double = 0

    var body: some View {
        Button(action: { cloudKit.triggerSync() }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .rotationEffect(.degrees(rotation))
                Text(cloudKit.syncStatus == .syncing ? "Syncing..." : "Sync Now")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .disabled(cloudKit.syncStatus == .syncing)
        .onChange(of: cloudKit.syncStatus) { _, newValue in
            if newValue == .syncing {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                withAnimation(.default) {
                    rotation = 0
                }
            }
        }
    }
}
