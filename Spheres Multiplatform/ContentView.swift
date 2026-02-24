//
//  ContentView.swift
//  Spheres - Smart Life Manager
//
//  Created by Naomi Ivie on 10/20/25.
//
//  Main app shell: ContentView, SidebarView, and navigation.
//  All view components have been extracted into separate files:
//    SharedComponents.swift, HomeView.swift, SpheresView.swift,
//    SphereDetailView.swift, InboxView.swift, MindView.swift,
//    ScheduleView.swift, SettingsView.swift, QuickCaptureOverlay.swift
//

import SwiftUI
import SwiftData

// MARK: - Data Models (moved to Models.swift)
// SphereModel, OpenLoopModel, InboxItemModel are now SwiftData @Model classes
// AISuggestion remains a struct for transient AI suggestion data

// MARK: - Main App View
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \OpenLoopModel.createdDate) private var allLoops: [OpenLoopModel]
    @StateObject private var calendarService = CalendarService.shared
    @State private var selectedTab: Tab = .spheres
    @State private var showingQuickCapture = false

    enum Tab: String, CaseIterable {
        case spheres = "Spheres"
        case home = "Home"
        case schedule = "Schedule"
        case inbox = "Inbox"
        case mind = "Mind"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .spheres: return "circle.grid.2x2.fill"
            case .home: return "house.fill"
            case .schedule: return "calendar"
            case .inbox: return "tray.fill"
            case .mind: return "brain.head.profile"
            case .settings: return "gear"
            }
        }
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("defaultView") private var defaultView: String = "home"
    @State private var showingOnboarding = false
    @State private var hasAppliedDefaultView = false

    // Proactive AI scheduling
    @State private var showingProactivePopup = false
    @State private var proactiveLoop: OpenLoopModel?
    @State private var proactiveSlot: CalendarService.FreeSlot?
    @State private var proactiveReason: String = ""

    // Track scheduled loop IDs to avoid suggesting them again
    @AppStorage("scheduledLoopIds") private var scheduledLoopIdsString: String = ""

    private var scheduledLoopIds: Set<String> {
        Set(scheduledLoopIdsString.components(separatedBy: ",").filter { !$0.isEmpty })
    }

    private func markLoopAsScheduled(_ loop: OpenLoopModel) {
        var ids = scheduledLoopIds
        ids.insert(loop.id.uuidString)
        scheduledLoopIdsString = ids.joined(separator: ",")
    }

    var body: some View {
        ZStack {
            SpheresTheme.background
                .ignoresSafeArea()

            HStack(spacing: 0) {
                SidebarView(selectedTab: $selectedTab, showingQuickCapture: $showingQuickCapture)

                Rectangle()
                    .fill(SpheresTheme.border)
                    .frame(width: 1)

                ZStack {
                    switch selectedTab {
                    case .spheres:
                        SpheresView()
                    case .home:
                        HomeView()
                    case .schedule:
                        ScheduleView()
                    case .inbox:
                        InboxView()
                    case .mind:
                        MindView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showingQuickCapture {
                QuickCaptureOverlay(isPresented: $showingQuickCapture)
            }

            if showingOnboarding {
                SmartSetupOnboardingFlow(isPresented: $showingOnboarding)
            }

            if showingProactivePopup, let loop = proactiveLoop, let slot = proactiveSlot {
                ProactiveSchedulingPopup(
                    isPresented: $showingProactivePopup,
                    loop: loop,
                    suggestedSlot: slot,
                    reason: proactiveReason,
                    onScheduled: { markLoopAsScheduled(loop) },
                    onSeeDay: {
                        showingProactivePopup = false
                        selectedTab = .schedule
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
        // Keyboard shortcuts
        .keyboardShortcut("n", modifiers: [.command]) // handled below
        .background(
            Group {
                Button("") { showingQuickCapture.toggle() }
                    .keyboardShortcut("n", modifiers: [.command])
                    .hidden()

                Button("") { selectedTab = .home }
                    .keyboardShortcut("1", modifiers: [.command])
                    .hidden()

                Button("") { selectedTab = .spheres }
                    .keyboardShortcut("2", modifiers: [.command])
                    .hidden()

                Button("") { selectedTab = .schedule }
                    .keyboardShortcut("3", modifiers: [.command])
                    .hidden()

                Button("") { selectedTab = .inbox }
                    .keyboardShortcut("4", modifiers: [.command])
                    .hidden()

                Button("") { selectedTab = .mind }
                    .keyboardShortcut("5", modifiers: [.command])
                    .hidden()

                Button("") { selectedTab = .settings }
                    .keyboardShortcut(",", modifiers: [.command])
                    .hidden()
            }
        )
        .onAppear {
            // Load user profile for personalization
            PersonalizationService.shared.loadProfile(modelContext: modelContext)

            if !hasCompletedOnboarding {
                showingOnboarding = true
            }
            if !hasAppliedDefaultView {
                hasAppliedDefaultView = true
                if let tab = Tab.allCases.first(where: { $0.rawValue.lowercased() == defaultView }) {
                    selectedTab = tab
                }
            }
            // Check for proactive scheduling after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                checkForProactiveScheduling()
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, newValue in
            if !newValue {
                showingOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showQuickCapture)) { _ in
            showingQuickCapture = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showProactivePopup)) { _ in
            checkForProactiveScheduling()
        }
    }

    // Track loops that have been shown this session to avoid repeats
    @State private var shownLoopIdsThisSession: Set<String> = []

    private func checkForProactiveScheduling() {
        // Find high-priority or due-today loops that aren't completed or already scheduled
        let calendar = Calendar.current
        let scheduledIds = scheduledLoopIds
        let candidates = allLoops.filter { loop in
            // Skip completed loops
            guard !loop.isCompleted else { return false }

            // Skip already-scheduled loops
            guard !scheduledIds.contains(loop.id.uuidString) else { return false }

            // Skip loops already shown this session
            guard !shownLoopIdsThisSession.contains(loop.id.uuidString) else { return false }

            // Due today or overdue
            if let due = loop.dueDate {
                if due <= Date() || calendar.isDateInToday(due) {
                    return true
                }
            }

            // High priority (1, 2, or 3)
            return loop.importance <= 3
        }.sorted { l1, l2 in
            // Prioritize overdue, then due today, then by importance
            let now = Date()
            let l1Overdue = (l1.dueDate ?? .distantFuture) < now
            let l2Overdue = (l2.dueDate ?? .distantFuture) < now
            if l1Overdue != l2Overdue { return l1Overdue }
            return l1.importance < l2.importance
        }

        guard let topLoop = candidates.first else {
            print("[Proactive] Skipped: no matching loops found (total: \(allLoops.count))")
            return
        }

        print("[Proactive] Found candidate: \(topLoop.content)")

        // Find a free slot (or create a default one if no calendar access)
        let duration = topLoop.estimatedMinutes ?? 60
        var slot: CalendarService.FreeSlot?

        if calendarService.hasAccess {
            let freeSlots = calendarService.findFreeSlots(forDuration: duration)
            slot = freeSlots.first
            print("[Proactive] Calendar access: yes, found \(freeSlots.count) slots")
        }

        // If no calendar access or no slots found, suggest a sensible default time
        if slot == nil {
            let now = Date()
            var targetHour = calendar.component(.hour, from: now) + 1

            // Clamp to reasonable working hours (9am - 6pm)
            if targetHour < 9 {
                targetHour = 9
            } else if targetHour >= 18 {
                // Too late today, suggest tomorrow at 9am
                if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                    var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                    components.hour = 9
                    components.minute = 0
                    if let startTime = calendar.date(from: components),
                       let endTime = calendar.date(byAdding: .minute, value: duration, to: startTime) {
                        slot = CalendarService.FreeSlot(startDate: startTime, endDate: endTime)
                        print("[Proactive] Created tomorrow slot: \(startTime)")
                    }
                }
            } else {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = targetHour
                components.minute = 0
                if let startTime = calendar.date(from: components),
                   let endTime = calendar.date(byAdding: .minute, value: duration, to: startTime) {
                    slot = CalendarService.FreeSlot(startDate: startTime, endDate: endTime)
                    print("[Proactive] Created default slot: \(startTime)")
                }
            }
        }

        guard let finalSlot = slot else {
            print("[Proactive] Skipped: couldn't create time slot")
            return
        }

        // Build the reason
        var reason: String
        if let due = topLoop.dueDate {
            if due < Date() {
                reason = "This is overdue — let's get it done!"
            } else if calendar.isDateInToday(due) {
                reason = "This is due today"
            } else {
                reason = "High priority task"
            }
        } else if topLoop.importance <= 2 {
            reason = "High priority — you've got time now"
        } else {
            reason = "This has been on your list for a bit"
        }

        proactiveLoop = topLoop
        proactiveSlot = finalSlot
        proactiveReason = reason
        shownLoopIdsThisSession.insert(topLoop.id.uuidString)
        showingProactivePopup = true
        print("[Proactive] Showing popup for loop: \(topLoop.content)")
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var showingQuickCapture: Bool
    @Query(filter: #Predicate<OpenLoopModel> { $0.sphere == nil && !$0.isCompleted }) private var inboxItems: [OpenLoopModel]

    var body: some View {
        VStack(spacing: 0) {
            // Logo
            HStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [SpheresTheme.accent, SpheresTheme.accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "circle.grid.3x3.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )

                Text("Spheres")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)

            // Quick Capture Button
            Button(action: { showingQuickCapture = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Quick Capture")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(SpheresTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(SpheresTheme.accent)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            // Navigation Items
            VStack(spacing: 4) {
                ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                    SidebarItem(
                        icon: tab.icon,
                        title: tab.rawValue,
                        isSelected: selectedTab == tab,
                        badge: tab == .inbox ? (inboxItems.isEmpty ? nil : inboxItems.count) : nil
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Sync Status + Update
            HStack(spacing: 8) {
                EnhancedSignInStatus()
                AppUpdateButton()
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 200)
        .background(
            Color(red: 0.06, green: 0.06, blue: 0.07)
                .ignoresSafeArea()
        )
        .compositingGroup()
    }
}

// MARK: - Sidebar Status Bar (Sign-in + Update combined)
struct AppUpdateButton: View {
    @State private var isHovering = false
    @State private var isUpdating = false
    @State private var rotation: Double = 0

    var body: some View {
        Button(action: { runUpdate() }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                    .rotationEffect(.degrees(rotation))

                if isHovering || isUpdating {
                    Text(isUpdating ? "Updating..." : "Update")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .foregroundColor(SpheresTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(SpheresTheme.accent.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(SpheresTheme.accent.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isUpdating)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }

    private func runUpdate() {
        isUpdating = true
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            rotation = 360
        }

        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [
                "/Users/naomiivie/Downloads/App/Spheres Mac - Version 1.0 Dec 2025/auto_update.py",
                "--force",
                "--skip-pull"
            ]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try? process.run()
            process.waitUntilExit()

            await MainActor.run {
                withAnimation(.default) { rotation = 0 }
                isUpdating = false
            }
        }
    }
}

struct SidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var badge: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))

                Spacer()

                if let badge = badge {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(SpheresTheme.accent)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? SpheresTheme.textPrimary : SpheresTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? SpheresTheme.surfaceHover : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
