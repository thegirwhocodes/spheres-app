//
//  OnboardingFlow.swift
//  Spheres - Smart Life Manager
//
//  Privacy-first onboarding with clear permissions
//

import SwiftUI

// MARK: - Onboarding Flow
struct OnboardingFlow: View {
    @Binding var isPresented: Bool
    @StateObject private var privacySettings = PrivacySettings()
    @State private var currentStep: OnboardingStep = .welcome
    @State private var isAnimating = false
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case privacyPromise = 1
        case permissions = 2
        case aiExplanation = 3
        case iCloudSync = 4
        case complete = 5
        
        var progress: CGFloat {
            return CGFloat(self.rawValue) / CGFloat(OnboardingStep.allCases.count - 1)
        }
    }
    
    var body: some View {
        ZStack {
            SpheresTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                ProgressBar(progress: currentStep.progress)
                    .padding(.horizontal, 40)
                    .padding(.top, 24)
                
                // Content
                Group {
                    switch currentStep {
                    case .welcome:
                        WelcomeStep()
                    case .privacyPromise:
                        PrivacyPromiseStep()
                    case .permissions:
                        PermissionsStep(settings: privacySettings)
                    case .aiExplanation:
                        AIExplanationStep(settings: privacySettings)
                    case .iCloudSync:
                        iCloudSyncStep()
                    case .complete:
                        CompleteStep(settings: privacySettings)
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep != .welcome {
                        Button("Back") {
                            withAnimation {
                                currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
                            }
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            if currentStep == .complete {
                                finishOnboarding()
                            } else {
                                currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .complete
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text(buttonText)
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SpheresTheme.accent)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private var buttonText: String {
        switch currentStep {
        case .complete: return "Get Started"
        default: return "Continue"
        }
    }
    
    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(privacySettings.iMessageEnabled, forKey: "permission.imessage")
        UserDefaults.standard.set(privacySettings.gmailEnabled, forKey: "permission.gmail")
        UserDefaults.standard.set(privacySettings.calendarEnabled, forKey: "permission.calendar")
        UserDefaults.standard.set(privacySettings.aiProcessingEnabled, forKey: "permission.aiProcessing")
        isPresented = false
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(SpheresTheme.surface)
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [SpheresTheme.accent, SpheresTheme.accent.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 6)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated logo
            ZStack {
                Circle()
                    .fill(SpheresTheme.accent.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(SpheresTheme.accent.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 44))
                    .foregroundColor(SpheresTheme.accent)
            }
            
            VStack(spacing: 12) {
                Text("Welcome to Spheres")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SpheresTheme.textPrimary)
                
                Text("Your intelligent life manager that helps you capture tasks from messages, emails, and notes — automatically.")
                    .font(.system(size: 15))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Privacy badge
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                Text("Privacy-first design")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.1))
            )
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Privacy Promise Step
struct PrivacyPromiseStep: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundColor(SpheresTheme.accent)
            
            Text("Your Data, Your Control")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(SpheresTheme.textPrimary)
            
            Text("We believe you should always know what's happening with your data.")
                .font(.system(size: 14))
                .foregroundColor(SpheresTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                PrivacyPromiseRow(
                    icon: "iphone",
                    title: "On-Device First",
                    description: "Your data stays on your device by default"
                )
                
                PrivacyPromiseRow(
                    icon: "eye.slash.fill",
                    title: "No Hidden Access",
                    description: "You choose what Spheres can see, app by app"
                )
                
                PrivacyPromiseRow(
                    icon: "arrow.up.bin.fill",
                    title: "Delete Anytime",
                    description: "Remove your data instantly — no questions asked"
                )
                
                PrivacyPromiseRow(
                    icon: "checkmark.shield.fill",
                    title: "Encrypted Everything",
                    description: "All data is encrypted in transit and at rest"
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct PrivacyPromiseRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(SpheresTheme.accent)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(SpheresTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SpheresTheme.surface)
        )
    }
}

// MARK: - Permissions Step
struct PermissionsStep: View {
    @ObservedObject var settings: PrivacySettings
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "app.badge.checkmark.fill")
                .font(.system(size: 44))
                .foregroundColor(SpheresTheme.accent)
            
            Text("Connect Your Apps")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(SpheresTheme.textPrimary)
            
            Text("Choose what Spheres can access. You can change this anytime in Settings.")
                .font(.system(size: 14))
                .foregroundColor(SpheresTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                PermissionToggleCard(
                    icon: "message.fill",
                    iconColor: .green,
                    title: "iMessage",
                    description: "Find tasks in your text messages",
                    privacyNote: "Messages stay on your device",
                    isEnabled: $settings.iMessageEnabled
                )
                
                PermissionToggleCard(
                    icon: "envelope.fill",
                    iconColor: .blue,
                    title: "Gmail",
                    description: "Scan emails for action items",
                    privacyNote: "AI processes text securely",
                    isEnabled: $settings.gmailEnabled
                )
                
                PermissionToggleCard(
                    icon: "calendar",
                    iconColor: .red,
                    title: "Calendar",
                    description: "Find free time for your tasks",
                    privacyNote: "Read-only access",
                    isEnabled: $settings.calendarEnabled
                )
            }
            .padding(.horizontal, 20)
            
            // Skip option
            Button("Skip for now — I'll add these later") {
                settings.iMessageEnabled = false
                settings.gmailEnabled = false
                settings.calendarEnabled = false
            }
            .buttonStyle(GhostButtonStyle())
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct PermissionToggleCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let privacyNote: String
    @Binding var isEnabled: Bool
    
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
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(SpheresTheme.textSecondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                    Text(privacyNote)
                        .font(.system(size: 11))
                }
                .foregroundColor(.green.opacity(0.8))
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
                        .stroke(isEnabled ? SpheresTheme.accent.opacity(0.5) : SpheresTheme.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - AI Explanation Step
struct AIExplanationStep: View {
    @ObservedObject var settings: PrivacySettings
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 44))
                .foregroundColor(SpheresTheme.accent)
            
            Text("How AI Helps You")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(SpheresTheme.textPrimary)
            
            Text("Spheres uses AI to find tasks in your messages. Here's how we keep it private:")
                .font(.system(size: 14))
                .foregroundColor(SpheresTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                AIExplanationRow(
                    number: "1",
                    title: "Text is encrypted",
                    description: "Sent securely using HTTPS/TLS 1.3"
                )
                
                AIExplanationRow(
                    number: "2",
                    title: "Processed instantly",
                    description: "We don't store your messages on our servers"
                )
                
                AIExplanationRow(
                    number: "3",
                    title: "Only tasks are saved",
                    description: "We extract tasks, then discard the original text"
                )
            }
            .padding(.horizontal, 20)
            
            // Enable AI toggle
            VStack(spacing: 12) {
                Toggle(isOn: $settings.aiProcessingEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable AI Processing")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)
                        
                        Text("Required for Gmail and advanced iMessage features")
                            .font(.system(size: 13))
                            .foregroundColor(SpheresTheme.textSecondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SpheresTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(settings.aiProcessingEnabled ? SpheresTheme.accent.opacity(0.5) : SpheresTheme.border, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            
            // Note about no API key needed
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("No API key needed — we handle everything")
                    .font(.system(size: 12))
                    .foregroundColor(SpheresTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct AIExplanationRow: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(SpheresTheme.accent)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(SpheresTheme.accent.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(SpheresTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SpheresTheme.surface)
        )
    }
}

// MARK: - iCloud Sync Step
struct iCloudSyncStep: View {
    @StateObject private var cloudKit = CloudKitService.shared
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "icloud.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Sync Across Devices")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(SpheresTheme.textPrimary)
            
            Text("Access your spheres on iPhone, iPad, and Mac with iCloud.")
                .font(.system(size: 14))
                .foregroundColor(SpheresTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            // iCloud Status Card
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: cloudKit.isSignedIn ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(cloudKit.isSignedIn ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cloudKit.isSignedIn ? "You're signed in to iCloud" : "Sign in to iCloud")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)
                        
                        Text(cloudKit.isSignedIn 
                            ? "Your data will sync across all your devices"
                            : "Go to System Settings to sign in")
                            .font(.system(size: 13))
                            .foregroundColor(SpheresTheme.textSecondary)
                    }
                    
                    Spacer()
                }
                
                if cloudKit.isSignedIn {
                    Divider()
                    
                    Toggle(isOn: $iCloudSyncEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable iCloud Sync")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(SpheresTheme.textPrimary)
                            
                            Text("Your data is encrypted end-to-end")
                                .font(.system(size: 12))
                                .foregroundColor(SpheresTheme.textSecondary)
                        }
                    }
                    .toggleStyle(.switch)
                } else {
                    Button(action: { cloudKit.openSystemSettings() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Open System Settings")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SpheresTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(cloudKit.isSignedIn ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            
            // Benefits
            HStack(spacing: 24) {
                BenefitItem(icon: "iphone", text: "iPhone")
                BenefitItem(icon: "ipad", text: "iPad")
                BenefitItem(icon: "laptopcomputer", text: "Mac")
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .onAppear {
            cloudKit.checkAccountStatus()
        }
    }
}

struct BenefitItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(SpheresTheme.textSecondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.textTertiary)
        }
    }
}

// MARK: - Complete Step
struct CompleteStep: View {
    @ObservedObject var settings: PrivacySettings
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
            }
            
            Text("You're All Set!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(SpheresTheme.textPrimary)
            
            // Summary of what's enabled
            VStack(spacing: 10) {
                Text("Here's what you've enabled:")
                    .font(.system(size: 14))
                    .foregroundColor(SpheresTheme.textSecondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    if settings.iMessageEnabled {
                        EnabledItem(icon: "message.fill", text: "iMessage access")
                    }
                    if settings.gmailEnabled {
                        EnabledItem(icon: "envelope.fill", text: "Gmail access")
                    }
                    if settings.calendarEnabled {
                        EnabledItem(icon: "calendar", text: "Calendar access")
                    }
                    if settings.aiProcessingEnabled {
                        EnabledItem(icon: "sparkles", text: "AI processing")
                    }
                    if !settings.iMessageEnabled && !settings.gmailEnabled && !settings.calendarEnabled {
                        EnabledItem(icon: "hand.raised.fill", text: "Manual entry only")
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SpheresTheme.surface)
                )
            }
            
            Text("You can change any of these in Settings anytime.")
                .font(.system(size: 13))
                .foregroundColor(SpheresTheme.textTertiary)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct EnabledItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(SpheresTheme.accent)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(SpheresTheme.textPrimary)
        }
    }
}

// MARK: - Privacy Settings Model
class PrivacySettings: ObservableObject {
    @Published var iMessageEnabled = false
    @Published var gmailEnabled = false
    @Published var calendarEnabled = false
    @Published var aiProcessingEnabled = false
    @Published var onDeviceOnly = true
}

// MARK: - Preview
#Preview {
    OnboardingFlow(isPresented: .constant(true))
}
