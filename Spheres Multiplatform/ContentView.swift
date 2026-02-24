//
//  ContentView.swift
//  Spheres - Smart Life Manager
//
//  Created by Naomi Ivie on 10/20/25.
//

import SwiftUI
import SwiftData
import AppKit
import EventKit
import Speech

// MARK: - Theme
struct SpheresTheme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let surface = Color.white.opacity(0.05)
    static let surfaceHover = Color.white.opacity(0.08)
    static let surfaceElevated = Color.white.opacity(0.07)
    static let border = Color.white.opacity(0.1)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.4)
    static let textMuted = Color.white.opacity(0.25)
    static let accent = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let accentGlow = Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.3)
}

// MARK: - Icon Library with Styles
struct IconLibrary {
    // Icon style definitions
    enum IconStyle: String, CaseIterable {
        case filled = "Filled"
        case outline = "Outline"
        case bold = "Bold"
        case whimsical = "Whimsical"
        case minimal = "Minimal"

        var description: String {
            switch self {
            case .filled: return "Classic filled icons"
            case .outline: return "Light outlined icons"
            case .bold: return "Heavy, bold icons"
            case .whimsical: return "Playful, fun icons"
            case .minimal: return "Simple, clean icons"
            }
        }
    }

    // Base icon set (will be transformed by style)
    static let baseIcons: [(String, [String])] = [
        ("Life", ["heart", "star", "sparkles", "leaf", "sun.max", "moon", "cloud", "bolt"]),
        ("People", ["person", "person.2", "figure.2.and.child.holdinghands", "figure.walk", "figure.run", "hand.raised", "brain.head.profile", "face.smiling"]),
        ("Work", ["briefcase", "doc", "folder", "tray", "envelope", "phone", "desktopcomputer", "laptopcomputer"]),
        ("Learning", ["book", "graduationcap", "lightbulb", "pencil", "bookmark", "newspaper", "text.book.closed", "menucard"]),
        ("Health", ["heart.circle", "cross", "pills", "bandage", "stethoscope", "lungs", "figure.mind.and.body", "bed.double"]),
        ("Creative", ["paintbrush", "pencil.tip", "camera", "music.note", "guitars", "theatermasks", "film", "photo"]),
        ("Finance", ["dollarsign.circle", "creditcard", "banknote", "chart.line.uptrend.xyaxis", "building.columns", "house", "car", "airplane"]),
        ("Spiritual", ["hands.sparkles", "book.closed", "flame", "water.waves", "globe.americas", "peacesign", "infinity", "waveform.path"]),
    ]

    // Whimsical alternatives (different icon names for playful feel)
    static let whimsicalIcons: [(String, [String])] = [
        ("Life", ["heart.fill", "star.circle.fill", "sparkles", "leaf.arrow.triangle.circlepath", "sun.max.trianglebadge.exclamationmark", "moon.stars.fill", "cloud.sun.fill", "bolt.heart.fill"]),
        ("People", ["person.crop.circle.fill", "person.2.circle.fill", "figure.2.and.child.holdinghands", "figure.dance", "figure.wave", "hand.wave.fill", "brain", "face.smiling.inverse"]),
        ("Work", ["bag.fill", "doc.richtext.fill", "folder.badge.gearshape", "tray.2.fill", "envelope.open.fill", "phone.bubble.fill", "display", "laptopcomputer.and.iphone"]),
        ("Learning", ["books.vertical.fill", "graduationcap.fill", "lightbulb.max.fill", "pencil.and.scribble", "bookmark.square.fill", "newspaper.circle.fill", "character.book.closed.fill", "list.bullet.clipboard.fill"]),
        ("Health", ["heart.text.square.fill", "cross.circle.fill", "pills.circle.fill", "bandage.fill", "staroflife.fill", "lungs.fill", "figure.yoga", "bed.double.circle.fill"]),
        ("Creative", ["paintpalette.fill", "pencil.tip.crop.circle.badge.plus", "camera.aperture", "music.quarternote.3", "pianokeys.inverse", "theatermask.and.paintbrush.fill", "film.stack.fill", "photo.stack.fill"]),
        ("Finance", ["dollarsign.arrow.circlepath", "creditcard.trianglebadge.exclamationmark", "banknote.fill", "chart.line.uptrend.xyaxis.circle.fill", "building.columns.circle.fill", "house.lodge.fill", "car.front.waves.up.fill", "airplane.departure"]),
        ("Spiritual", ["hands.and.sparkles.fill", "text.book.closed.fill", "flame.circle.fill", "drop.triangle.fill", "globe.central.south.asia.fill", "peacesign", "infinity.circle.fill", "waveform.circle.fill"]),
    ]

    static func icons(for style: IconStyle) -> [(String, [String])] {
        switch style {
        case .filled:
            return baseIcons.map { ($0.0, $0.1.map { iconName in
                // Add .fill suffix where appropriate
                if iconName.contains(".") && !iconName.hasSuffix(".fill") && !["desktopcomputer", "laptopcomputer", "stethoscope", "peacesign", "infinity"].contains(iconName) {
                    return iconName + ".fill"
                } else if !iconName.contains(".") && !["desktopcomputer", "laptopcomputer", "stethoscope", "peacesign", "infinity", "pencil"].contains(iconName) {
                    return iconName + ".fill"
                }
                return iconName
            })}
        case .outline:
            return baseIcons // Already base (unfilled) icons
        case .bold:
            return baseIcons.map { ($0.0, $0.1.map { iconName in
                if !iconName.contains(".") {
                    return iconName + ".circle.fill"
                }
                return iconName + ".fill"
            })}
        case .whimsical:
            return whimsicalIcons
        case .minimal:
            return baseIcons // Same as outline for minimal
        }
    }

    static var allIcons: [String] {
        baseIcons.flatMap { $0.1 }
    }
}

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
        // Skip onboarding check when triggered manually from settings
        // guard hasCompletedOnboarding else {
        //     print("[Proactive] Skipped: onboarding not complete")
        //     return
        // }

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
                "--force"
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

// MARK: - Spheres View (Compact Grid)
struct SpheresView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\SphereModel.priorityRank), SortDescriptor(\SphereModel.createdDate)]) private var spheres: [SphereModel]

    @State private var showingAddSphere = false
    @State private var quickViewSphere: SphereModel? = nil
    @State private var selectedSphereForFullView: SphereModel? = nil
    @State private var hasSeededData = false
    @State private var draggingSphere: SphereModel? = nil

    let mockSuggestions: [AISuggestion] = [
        AISuggestion(
            title: "60% done with presentation",
            description: "I found a 2-hour slot Saturday morning. Want me to block it off?",
            type: .schedule
        ),
        AISuggestion(
            title: "Consider adding Finances",
            description: "You've mentioned 'budget' and 'savings' 6 times recently.",
            type: .newSphere
        ),
    ]

    let columns = [
        GridItem(.flexible(minimum: 180), spacing: 16),
        GridItem(.flexible(minimum: 180), spacing: 16),
        GridItem(.flexible(minimum: 180), spacing: 16)
    ]

    var body: some View {
        ZStack {
            if let sphere = selectedSphereForFullView {
                // Full Page Sphere View
                SphereFullPageView(
                    sphere: sphere,
                    loops: (sphere.loops ?? []).sorted { $0.importance < $1.importance },
                    allSpheres: spheres,
                    onBack: { selectedSphereForFullView = nil }
                )
                .transition(.move(edge: .trailing))
            } else {
                // Grid View
                VStack(spacing: 0) {
                    // Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Life")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SpheresTheme.textPrimary)

                            Text("\(spheres.count) spheres")
                                .font(.system(size: 14))
                                .foregroundColor(SpheresTheme.textSecondary)
                        }

                        Spacer()

                        Button(action: { showingAddSphere = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Add Sphere")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .buttonStyle(AccentButtonStyle())
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                    // Main Content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Spheres Grid (Drag to Reorder)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(spheres) { sphere in
                                    CompactSphereCard(
                                        sphere: sphere,
                                        loops: (sphere.loops ?? []).sorted { $0.importance < $1.importance },
                                        onTap: {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                selectedSphereForFullView = sphere
                                            }
                                        },
                                        onQuickView: {
                                            quickViewSphere = sphere
                                        }
                                    )
                                    .opacity(draggingSphere?.id == sphere.id ? 0.5 : 1.0)
                                    .draggable(sphere.id.uuidString) {
                                        // Drag preview
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(sphere.color.opacity(0.8))
                                            .frame(width: 120, height: 80)
                                            .overlay(
                                                VStack(spacing: 4) {
                                                    Image(systemName: sphere.icon)
                                                        .font(.system(size: 20))
                                                    Text(sphere.name)
                                                        .font(.system(size: 11, weight: .medium))
                                                }
                                                .foregroundColor(.white)
                                            )
                                            .onAppear { draggingSphere = sphere }
                                    }
                                    .dropDestination(for: String.self) { items, _ in
                                        guard let droppedId = items.first,
                                              let droppedUUID = UUID(uuidString: droppedId),
                                              let sourceSphere = spheres.first(where: { $0.id == droppedUUID }),
                                              sourceSphere.id != sphere.id else {
                                            return false
                                        }

                                        // Reorder: move source to target's position
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            reorderSpheres(from: sourceSphere, to: sphere)
                                        }
                                        draggingSphere = nil
                                        return true
                                    }
                                }
                            }
                            .padding(.horizontal, 32)

                            // AI Insights Section
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11))
                                        .foregroundColor(SpheresTheme.accent)

                                    Text("AI Insights")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(SpheresTheme.textSecondary)

                                    Text("— your companion")
                                        .font(.system(size: 10))
                                        .foregroundColor(SpheresTheme.textTertiary)
                                }

                                HStack(spacing: 12) {
                                    ForEach(mockSuggestions) { suggestion in
                                        AIInsightCard(suggestion: suggestion)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.top, 4)
                            .padding(.bottom, 20)
                        }
                    }
                }
                .transition(.move(edge: .leading))
            }
        }
        .onAppear {
            if !hasSeededData {
                DataManager.shared.cleanupDefaultDataIfNeeded(modelContext: modelContext)
                hasSeededData = true
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedSphereForFullView != nil)
        .sheet(isPresented: $showingAddSphere) {
            AddSphereSheet(isPresented: $showingAddSphere)
        }
        .sheet(item: $quickViewSphere) { sphere in
            SphereDetailSheet(sphere: sphere, loops: (sphere.loops ?? []).sorted { $0.importance < $1.importance }, allSpheres: spheres)
        }
    }

    // MARK: - Reorder Spheres
    private func reorderSpheres(from source: SphereModel, to target: SphereModel) {
        let sourceIndex = spheres.firstIndex(where: { $0.id == source.id }) ?? 0
        let targetIndex = spheres.firstIndex(where: { $0.id == target.id }) ?? 0

        // Update priority ranks
        if sourceIndex < targetIndex {
            // Moving down: shift items up
            for i in (sourceIndex + 1)...targetIndex {
                spheres[i].priorityRank = i - 1
            }
            source.priorityRank = targetIndex
        } else {
            // Moving up: shift items down
            for i in targetIndex..<sourceIndex {
                spheres[i].priorityRank = i + 1
            }
            source.priorityRank = targetIndex
        }

        // Save changes
        try? modelContext.save()
    }
}

// MARK: - Compact Sphere Card (Gallery Style)
struct CompactSphereCard: View {
    let sphere: SphereModel
    let loops: [OpenLoopModel]
    let onTap: () -> Void
    let onQuickView: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 10) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(sphere.color.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [sphere.color, sphere.color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: sphere.icon)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sphere.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)

                        HStack(spacing: 4) {
                            Text("Rank \(sphere.priorityRank)")
                                .font(.system(size: 11))
                                .foregroundColor(SpheresTheme.textTertiary)

                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(SpheresTheme.textTertiary)

                            Text("\(loops.count) open")
                                .font(.system(size: 11))
                                .foregroundColor(SpheresTheme.textTertiary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .opacity(isHovered ? 1 : 0.5)
                }

                // Scrollable Loop Preview (only active loops)
                if !loops.filter({ !$0.isCompleted }).isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(loops.filter { !$0.isCompleted }.sorted { $0.importance < $1.importance }) { loop in
                                HStack(spacing: 8) {
                                    // Bullet in sphere color
                                    Circle()
                                        .fill(sphere.color.opacity(0.5))
                                        .frame(width: 5, height: 5)

                                    Text(loop.content)
                                        .font(.system(size: 13))
                                        .foregroundColor(SpheresTheme.textSecondary)
                                        .lineLimit(1)

                                    Spacer()

                                    // Progress pie
                                    MiniProgressPie(progress: loop.progress, color: sphere.color)
                                        .frame(width: 18, height: 18)

                                    // Priority number
                                    Text("\(loop.importance)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(SpheresTheme.textTertiary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }

                Spacer(minLength: 0)

                // Quick View Button
                if isHovered {
                    Button(action: {
                        onQuickView()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.system(size: 9))
                            Text("Quick View")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(SpheresTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(SpheresTheme.surfaceHover)
                        )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(14)
            .frame(height: 300)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(SpheresTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isHovered ? sphere.color.opacity(0.3) : SpheresTheme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        default: return SpheresTheme.textTertiary
        }
    }
}

// Simple horizontal progress bar
struct SimpleProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(SpheresTheme.border)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * progress)
            }
        }
    }
}

// MARK: - Progress Ring (original style)
struct FilledProgressPie: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(SpheresTheme.border, lineWidth: 2)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center percentage text
            Text("\(Int(progress * 100))")
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(SpheresTheme.textTertiary)
        }
    }
}

// Mini progress pie for compact sphere cards
struct MiniProgressPie: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(SpheresTheme.border, lineWidth: 1.5)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))")
                .font(.system(size: 6, weight: .medium))
                .foregroundColor(SpheresTheme.textTertiary)
        }
    }
}

// MARK: - AI Insight Card
struct AIInsightCard: View {
    let suggestion: AISuggestion
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForType)
                .font(.system(size: 10))
                .foregroundColor(SpheresTheme.accent)
                .frame(width: 22, height: 22)
                .background(SpheresTheme.accent.opacity(0.15))
                .clipShape(Circle())

            Text(suggestion.title)
                .font(.system(size: 11))
                .foregroundColor(SpheresTheme.textPrimary)
                .lineLimit(1)

            Button(actionLabel) {}
                .buttonStyle(SmallAccentButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SpheresTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isHovered ? SpheresTheme.accent.opacity(0.2) : SpheresTheme.border, lineWidth: 1)
                )
        )
        .onHover { isHovered = $0 }
    }

    var iconForType: String {
        switch suggestion.type {
        case .newSphere: return "plus.circle"
        case .resurface: return "arrow.counterclockwise"
        case .schedule: return "calendar"
        case .insight: return "lightbulb"
        }
    }

    var actionLabel: String {
        switch suggestion.type {
        case .newSphere: return "Create"
        case .resurface: return "View"
        case .schedule: return "Schedule"
        case .insight: return "View"
        }
    }
}

// MARK: - Sphere Full Page View
struct SphereFullPageView: View {
    let sphere: SphereModel
    let loops: [OpenLoopModel]
    let allSpheres: [SphereModel]
    let onBack: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddLoop = false
    @State private var draggedLoop: OpenLoopModel?
    @State private var showingEditSphere = false
    @State private var showingDeleteConfirmation = false
    @AppStorage("showCompletedLoops") private var showCompletedLoops: Bool = true

    private var activeLoops: [OpenLoopModel] {
        loops.filter { !$0.isCompleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var completedLoops: [OpenLoopModel] {
        loops.filter { $0.isCompleted }.sorted { $0.completedDate ?? $0.createdDate > $1.completedDate ?? $1.createdDate }
    }

    private var filteredLoops: [OpenLoopModel] {
        activeLoops
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack(spacing: 16) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        onBack()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(SpheresTheme.textSecondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Menu {
                    Button(action: { showingEditSphere = true }) {
                        Label("Edit Sphere", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Sphere", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(SpheresTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Sphere Header
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(sphere.color.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [sphere.color, sphere.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: sphere.color.opacity(0.3), radius: 10, x: 0, y: 4)

                    Image(systemName: sphere.icon)
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(sphere.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(SpheresTheme.textPrimary)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("Rank")
                                .font(.system(size: 12))
                                .foregroundColor(SpheresTheme.textTertiary)
                            Text("\(sphere.priorityRank)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(sphere.color)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(SpheresTheme.surface)
                        )

                        Text("\(loops.count) open loops")
                            .font(.system(size: 13))
                            .foregroundColor(SpheresTheme.textSecondary)
                    }

                    if !sphere.sphereDescription.isEmpty {
                        Text(sphere.sphereDescription)
                            .font(.system(size: 13))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                Button(action: { showingAddLoop = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add Loop")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .buttonStyle(AccentButtonStyle())
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)

            Divider()
                .background(SpheresTheme.border)

            // Loops List
            ScrollView {
                VStack(spacing: 20) {
                    // Active Loops Section
                    VStack(alignment: .leading, spacing: 12) {
                        if !activeLoops.isEmpty {
                            ForEach(activeLoops) { loop in
                                DetailLoopCard(loop: loop, sphereColor: sphere.color, allSpheres: allSpheres)
                                    .draggable(loop.id.uuidString) {
                                        // Drag preview
                                        Text(loop.content)
                                            .font(.system(size: 12))
                                            .padding(8)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.surface))
                                    }
                                    .dropDestination(for: String.self) { items, _ in
                                        guard let draggedIdStr = items.first,
                                              let draggedId = UUID(uuidString: draggedIdStr),
                                              draggedId != loop.id else { return false }
                                        reorderLoop(draggedId: draggedId, targetId: loop.id)
                                        return true
                                    } isTargeted: { isTargeted in
                                        // Visual feedback handled by opacity
                                    }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 32))
                                    .foregroundColor(SpheresTheme.textTertiary)

                                Text("No open loops")
                                    .font(.system(size: 14))
                                    .foregroundColor(SpheresTheme.textTertiary)

                                Button(action: { showingAddLoop = true }) {
                                    Text("Add your first loop")
                                        .font(.system(size: 13))
                                }
                                .buttonStyle(GhostButtonStyle())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }

                    // Completed count shown subtly at bottom
                    if !completedLoops.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.green.opacity(0.6))
                            Text("\(completedLoops.count) completed")
                                .font(.system(size: 11))
                                .foregroundColor(SpheresTheme.textMuted)
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(32)
            }
        }
        .background(SpheresTheme.background)
        .sheet(isPresented: $showingAddLoop) {
            AddLoopSheet(isPresented: $showingAddLoop, sphere: sphere)
        }
        .onAppear {
            // Assign sort orders if not set (all zeros)
            let sorted = loops.sorted { $0.importance < $1.importance }
            if sorted.allSatisfy({ $0.sortOrder == 0 }) && sorted.count > 1 {
                for (index, loop) in sorted.enumerated() {
                    loop.sortOrder = index
                }
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showingEditSphere) {
            EditSphereSheet(sphere: sphere, isPresented: $showingEditSphere)
        }
        .alert("Delete Sphere?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSphere()
            }
        } message: {
            Text("This will permanently delete \"\(sphere.name)\" and all its loops. This action cannot be undone.")
        }
    }

    private func deleteSphere() {
        // Delete all loops in this sphere first
        for loop in loops {
            modelContext.delete(loop)
        }
        // Delete the sphere
        modelContext.delete(sphere)
        try? modelContext.save()
        // Navigate back
        onBack()
    }

    private func reorderLoop(draggedId: UUID, targetId: UUID) {
        var ordered = filteredLoops
        guard let fromIndex = ordered.firstIndex(where: { $0.id == draggedId }),
              let toIndex = ordered.firstIndex(where: { $0.id == targetId }) else { return }

        let moved = ordered.remove(at: fromIndex)
        ordered.insert(moved, at: toIndex)

        for (index, loop) in ordered.enumerated() {
            loop.sortOrder = index
        }
        try? modelContext.save()
    }
}

// MARK: - Sphere Detail Sheet
struct SphereDetailSheet: View {
    let sphere: SphereModel
    let loops: [OpenLoopModel]
    var allSpheres: [SphereModel] = []
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddLoop = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(sphere.color.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [sphere.color, sphere.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: sphere.color.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: sphere.icon)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(sphere.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(SpheresTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text("Rank \(sphere.priorityRank)")
                            .font(.system(size: 12))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(SpheresTheme.surface)
                            .clipShape(Capsule())

                        Text("\(loops.count) open loops")
                            .font(.system(size: 12))
                            .foregroundColor(SpheresTheme.textSecondary)
                    }
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(SpheresTheme.surface)

            Divider()
                .background(SpheresTheme.border)

            // Loops List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(loops) { loop in
                        DetailLoopCard(loop: loop, sphereColor: sphere.color, allSpheres: allSpheres)
                    }

                    // Add Loop Button
                    Button(action: { showingAddLoop = true }) {
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                            Text("Add open loop")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(SpheresTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(SpheresTheme.border, style: StrokeStyle(lineWidth: 1, dash: [6]))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 500)
        .background(SpheresTheme.background)
        .sheet(isPresented: $showingAddLoop) {
            AddLoopSheet(isPresented: $showingAddLoop, sphere: sphere)
        }
    }
}

// MARK: - Detail Loop Card
struct DetailLoopCard: View {
    let loop: OpenLoopModel
    let sphereColor: Color
    var allSpheres: [SphereModel] = []
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    @State private var showingDeleteConfirm = false
    @State private var showingEditSheet = false
    @State private var timerTick = false  // Used to refresh timer display

    // Timer to update display
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 14) {
            // Progress Pie (larger for detail view)
            ZStack {
                Circle()
                    .stroke(SpheresTheme.border, lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: loop.progress)
                    .stroke(sphereColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)

                if loop.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(sphereColor)
                } else {
                    Text("\(Int(loop.progress * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                // Content
                Text(loop.content)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(loop.isCompleted ? SpheresTheme.textTertiary : SpheresTheme.textPrimary)
                    .strikethrough(loop.isCompleted)

                // Meta Row
                HStack(spacing: 10) {
                    // Priority
                    HStack(spacing: 3) {
                        Text("Priority")
                            .font(.system(size: 11))
                            .foregroundColor(SpheresTheme.textTertiary)

                        Text("\(loop.importance)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(sphereColor)
                    }

                    if let mins = loop.estimatedMinutes {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(formatTime(mins))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(SpheresTheme.textTertiary)
                    }

                    // Time spent tracking
                    if loop.timeSpentSeconds > 0 || loop.isTimerRunning {
                        HStack(spacing: 4) {
                            Image(systemName: loop.isTimerRunning ? "timer" : "hourglass")
                                .font(.system(size: 10))
                            Text(formatTimeSpent(loop.totalTimeSpent))
                                .font(.system(size: 11, weight: loop.isTimerRunning ? .semibold : .regular))
                                .id(timerTick) // Force refresh
                        }
                        .foregroundColor(loop.isTimerRunning ? sphereColor : SpheresTheme.textTertiary)
                    }

                    // Habit badge with streak
                    if loop.isHabit {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("\(loop.currentStreak)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(loop.currentStreak > 0 ? .orange : SpheresTheme.textTertiary)
                    }

                    if let dueDate = loop.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(formatDate(dueDate))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(dueDate < Date() ? .red : SpheresTheme.textTertiary)
                    }
                }

                // Actions
                if isHovered {
                    HStack(spacing: 8) {
                        Button(action: { deleteLoop() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                Text("Delete")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(SmallGhostButtonStyle())

                        Button(action: { showingEditSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                                Text("Edit")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(SmallGhostButtonStyle())

                        // Timer button
                        if loop.isTimerRunning {
                            Button(action: { toggleTimer() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 11))
                                    Text("Stop")
                                        .font(.system(size: 11))
                                }
                            }
                            .buttonStyle(SmallAccentButtonStyle())
                        } else {
                            Button(action: { toggleTimer() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 11))
                                    Text("Start")
                                        .font(.system(size: 11))
                                }
                            }
                            .buttonStyle(SmallGhostButtonStyle())
                        }

                        Spacer()

                        if loop.isCompleted {
                            Button(action: { toggleComplete() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 11))
                                    Text("Undo")
                                        .font(.system(size: 11))
                                }
                            }
                            .buttonStyle(SmallGhostButtonStyle())
                        } else {
                            Button(action: { toggleComplete() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11))
                                    Text("Done")
                                        .font(.system(size: 11))
                                }
                            }
                            .buttonStyle(SmallAccentButtonStyle())
                        }
                    }
                    .transition(.opacity)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(loop.isCompleted ? sphereColor.opacity(0.3) : SpheresTheme.border, lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditLoopSheet(isPresented: $showingEditSheet, loop: loop, allSpheres: allSpheres)
        }
        .onReceive(timer) { _ in
            if loop.isTimerRunning {
                timerTick.toggle()
            }
        }
    }

    private func toggleComplete() {
        DataManager.shared.toggleLoopCompletion(loop, modelContext: modelContext)
        // Also mark as scheduled so it never shows in proactive popup again
        if loop.isCompleted {
            var ids = Set(UserDefaults.standard.string(forKey: "scheduledLoopIds")?.components(separatedBy: ",").filter { !$0.isEmpty } ?? [])
            ids.insert(loop.id.uuidString)
            UserDefaults.standard.set(ids.joined(separator: ","), forKey: "scheduledLoopIds")
        }
    }

    private func deleteLoop() {
        DataManager.shared.deleteLoop(loop, modelContext: modelContext)
    }

    private func toggleTimer() {
        DataManager.shared.toggleTimer(loop, modelContext: modelContext)
    }

    func formatTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    func formatTimeSpent(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let mins = seconds / 60
            let secs = seconds % 60
            return secs > 0 ? "\(mins)m \(secs)s" : "\(mins)m"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }

    func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Completed Loop Card (Compact)
struct CompletedLoopCard: View {
    let loop: OpenLoopModel
    let sphereColor: Color
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.green.opacity(0.7))

            Text(loop.content)
                .font(.system(size: 13))
                .foregroundColor(SpheresTheme.textTertiary)
                .strikethrough()
                .lineLimit(1)

            Spacer()

            if let completedDate = loop.completedDate {
                Text(formatCompletedDate(completedDate))
                    .font(.system(size: 11))
                    .foregroundColor(SpheresTheme.textMuted)
            }

            if isHovered {
                HStack(spacing: 6) {
                    Button(action: { undoComplete() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10))
                            .foregroundColor(SpheresTheme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { deleteLoop() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SpheresTheme.surface.opacity(0.5))
        )
        .onHover { isHovered = $0 }
    }

    private func undoComplete() {
        DataManager.shared.toggleLoopCompletion(loop, modelContext: modelContext)
    }

    private func deleteLoop() {
        DataManager.shared.deleteLoop(loop, modelContext: modelContext)
    }

    private func formatCompletedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @Query(sort: \OpenLoopModel.createdDate) private var allLoops: [OpenLoopModel]
    @Query(sort: \SphereModel.priorityRank) private var spheres: [SphereModel]
    @StateObject private var aiService = AIService.shared
    @State private var aiSuggestions: [ResurfacingSuggestion] = []
    @State private var isLoadingAI = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 17 { return "Good afternoon" }
        else { return "Good evening" }
    }

    // Stats computed from real data
    private var completedThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allLoops.filter { $0.isCompleted && ($0.completedDate ?? $0.createdDate) > weekAgo }.count
    }

    private var openLoops: Int {
        allLoops.filter { !$0.isCompleted }.count
    }

    private var highPriority: Int {
        allLoops.filter { !$0.isCompleted && $0.importance <= 2 }.count
    }

    // Local resurfacing items (fallback): high priority, oldest first
    private var localResurfacingItems: [OpenLoopModel] {
        allLoops
            .filter { !$0.isCompleted && $0.importance <= 2 }
            .sorted { $0.createdDate < $1.createdDate }
            .prefix(5)
            .map { $0 }
    }

    // Total time spent this week
    private var totalTimeThisWeek: Int {
        allLoops.reduce(0) { $0 + $1.timeSpentSeconds }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(greeting)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(SpheresTheme.textPrimary)

                    Text("Here's what's on your mind today")
                        .font(.system(size: 15))
                        .foregroundColor(SpheresTheme.textSecondary)
                }
                .padding(.top, 8)

                // iCloud Sync Banner (shows once for new users)
                SyncSetupBanner()

                // Resurfacing Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("RESURFACING TODAY")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .tracking(1)

                        if aiService.hasAPIKey && !aiSuggestions.isEmpty {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.accent)
                        }

                        Spacer()

                        if isLoadingAI {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }

                    if !aiSuggestions.isEmpty {
                        // AI-powered suggestions with reasons
                        VStack(spacing: 10) {
                            ForEach(aiSuggestions) { suggestion in
                                ResurfaceItemWithReason(loop: suggestion.loop, reason: suggestion.reason)
                            }
                        }
                    } else if localResurfacingItems.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                            Text("No high-priority items right now!")
                                .font(.system(size: 14))
                                .foregroundColor(SpheresTheme.textSecondary)
                        }
                        .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(localResurfacingItems) { loop in
                                ResurfaceItemReal(loop: loop)
                            }
                        }
                    }
                }

                // Quick Stats
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR WEEK")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .tracking(1)

                    HStack(spacing: 16) {
                        StatCard(value: "\(completedThisWeek)", label: "Completed", icon: "checkmark.circle.fill", color: .green)
                        StatCard(value: "\(openLoops)", label: "Open Loops", icon: "circle.dotted", color: .orange)
                        StatCard(value: "\(highPriority)", label: "High Priority", icon: "exclamationmark.circle.fill", color: .red)
                    }

                    // Time tracked this week
                    if totalTimeThisWeek > 0 {
                        HStack(spacing: 16) {
                            StatCard(value: formatTotalTime(totalTimeThisWeek), label: "Time Tracked", icon: "clock.fill", color: .blue)
                        }
                    }
                }

                // Active habits with streaks
                let activeHabits = allLoops.filter { $0.isHabit && $0.currentStreak > 0 }
                if !activeHabits.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ACTIVE STREAKS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .tracking(1)

                        VStack(spacing: 8) {
                            ForEach(activeHabits.sorted { $0.currentStreak > $1.currentStreak }.prefix(3)) { habit in
                                HStack(spacing: 12) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)

                                    Text(habit.content)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(SpheresTheme.textPrimary)
                                        .lineLimit(1)

                                    Spacer()

                                    Text("\(habit.currentStreak) days")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.orange)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(SpheresTheme.surface)
                                )
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(32)
        }
        .onAppear {
            fetchAISuggestions()
        }
    }

    private func fetchAISuggestions() {
        let openLoops = allLoops.filter { !$0.isCompleted }
        guard !openLoops.isEmpty else { return }

        isLoadingAI = true
        Task {
            let suggestions = await aiService.getResurfacingSuggestions(loops: openLoops, spheres: spheres)
            await MainActor.run {
                aiSuggestions = suggestions
                isLoadingAI = false
            }
        }
    }

    func formatTotalTime(_ seconds: Int) -> String {
        if seconds < 3600 {
            return "\(seconds / 60)m"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// Resurfacing item with AI reason
struct ResurfaceItemWithReason: View {
    let loop: OpenLoopModel
    let reason: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // Importance dots
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i < loop.importance ? (loop.sphere?.color ?? SpheresTheme.accent) : SpheresTheme.border)
                        .frame(width: 5, height: 5)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(loop.content)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let sphere = loop.sphere {
                        Circle()
                            .fill(sphere.color)
                            .frame(width: 6, height: 6)
                        Text(sphere.name)
                            .font(.system(size: 11))
                    }
                    Text("•")
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundColor(SpheresTheme.accent)
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.accent)
                }
                .foregroundColor(SpheresTheme.textTertiary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
        )
        .onHover { isHovered = $0 }
    }
}

// Real data resurfacing item (no AI reason)
struct ResurfaceItemReal: View {
    let loop: OpenLoopModel
    @State private var isHovered = false

    private var daysOld: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: loop.createdDate, to: Date()).day ?? 0
    }

    var body: some View {
        HStack(spacing: 14) {
            // Importance dots
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i < loop.importance ? (loop.sphere?.color ?? SpheresTheme.accent) : SpheresTheme.border)
                        .frame(width: 5, height: 5)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(loop.content)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let sphere = loop.sphere {
                        Circle()
                            .fill(sphere.color)
                            .frame(width: 6, height: 6)
                        Text(sphere.name)
                            .font(.system(size: 11))
                    }
                    Text("•")
                    Text("\(daysOld)d ago")
                        .font(.system(size: 11))
                }
                .foregroundColor(SpheresTheme.textTertiary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
        )
        .onHover { isHovered = $0 }
    }
}

struct ResurfaceItem: View {
    let content: String
    let sphere: String
    let sphereColor: Color
    let importance: Int
    let daysOld: Int
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // Importance
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i < importance ? sphereColor : SpheresTheme.border)
                        .frame(width: 5, height: 5)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(content)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(sphereColor)
                        .frame(width: 6, height: 6)
                    Text(sphere)
                        .font(.system(size: 11))
                    Text("•")
                    Text("\(daysOld)d ago")
                        .font(.system(size: 11))
                }
                .foregroundColor(SpheresTheme.textTertiary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 6) {
                    Button(action: {}) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(TinyIconButtonStyle())

                    Button(action: {}) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(TinyIconButtonStyle())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
        )
        .onHover { isHovered = $0 }
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(SpheresTheme.textPrimary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(SpheresTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SpheresTheme.surface)
        )
    }
}

// MARK: - Inbox View
struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InboxItemModel.capturedDate, order: .reverse) private var inboxItems: [InboxItemModel]
    @Query(sort: \SphereModel.priorityRank) private var spheres: [SphereModel]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Inbox")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(SpheresTheme.textPrimary)

                        Text("\(inboxItems.count) items to process")
                            .font(.system(size: 14))
                            .foregroundColor(SpheresTheme.textSecondary)
                    }

                    Spacer()
                }

                if inboxItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(SpheresTheme.textTertiary)

                        Text("Inbox is empty")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(SpheresTheme.textSecondary)

                        Text("Use Quick Capture to add thoughts, tasks, or ideas")
                            .font(.system(size: 13))
                            .foregroundColor(SpheresTheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    VStack(spacing: 8) {
                        ForEach(inboxItems) { item in
                            InboxItemRow(item: item, spheres: spheres)
                        }
                    }
                }
            }
            .padding(32)
        }
    }
}

struct InboxItemRow: View {
    let item: InboxItemModel
    let spheres: [SphereModel]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var aiService = AIService.shared
    @State private var isHovered = false
    @State private var showingProcessSheet = false
    @State private var suggestedSphere: SphereModel?
    @State private var isLoadingSuggestion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Circle()
                    .stroke(SpheresTheme.border, lineWidth: 2)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.content)
                        .font(.system(size: 14))
                        .foregroundColor(SpheresTheme.textPrimary)

                    Text(timeAgo(from: item.capturedDate))
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.textTertiary)
                }

                Spacer()

                if isHovered {
                    HStack(spacing: 8) {
                        Button(action: { showingProcessSheet = true }) {
                            Image(systemName: "folder")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(IconButtonStyle())

                        Button(action: { deleteItem() }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(IconButtonStyle())
                    }
                }
            }

            // AI suggestion row
            if isLoadingSuggestion {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Finding best sphere...")
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
                .padding(.leading, 36)
                .padding(.top, 8)
            } else if let sphere = suggestedSphere {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(SpheresTheme.accent)

                    Text("Suggested:")
                        .font(.system(size: 11))
                        .foregroundColor(SpheresTheme.textTertiary)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(sphere.color)
                            .frame(width: 8, height: 8)
                        Text(sphere.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(sphere.color)
                    }

                    Spacer()

                    Button(action: { acceptSuggestion(sphere) }) {
                        Text("Accept")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(SpheresTheme.accent))
                    }
                    .buttonStyle(.plain)

                    Button(action: { showingProcessSheet = true }) {
                        Text("Edit")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(SpheresTheme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 36)
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
        )
        .onHover { isHovered = $0 }
        .sheet(isPresented: $showingProcessSheet) {
            ProcessInboxSheet(isPresented: $showingProcessSheet, item: item, spheres: spheres)
        }
        .onAppear {
            loadAISuggestion()
        }
    }

    private func loadAISuggestion() {
        guard aiService.hasAPIKey, suggestedSphere == nil else { return }
        isLoadingSuggestion = true

        Task {
            let suggested = await aiService.classifyInboxItem(item.content, spheres: spheres)
            await MainActor.run {
                suggestedSphere = suggested
                isLoadingSuggestion = false
            }
        }
    }

    private func acceptSuggestion(_ sphere: SphereModel) {
        // Create loop and delete inbox item
        DataManager.shared.processInboxItem(
            item,
            toSphere: sphere,
            importance: 3,
            modelContext: modelContext
        )
    }

    private func deleteItem() {
        DataManager.shared.deleteInboxItem(item, modelContext: modelContext)
    }

    func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        else if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        else { return "\(Int(interval / 86400))d ago" }
    }
}

// MARK: - Process Inbox Sheet
struct ProcessInboxSheet: View {
    @Binding var isPresented: Bool
    let item: InboxItemModel
    let spheres: [SphereModel]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var aiService = AIService.shared
    @State private var selectedSphere: SphereModel?
    @State private var suggestedSphere: SphereModel?
    @State private var importance: Int = 3
    @State private var isLoadingSuggestion = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Process Item")
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

            // Item content
            Text(item.content)
                .font(.system(size: 14))
                .foregroundColor(SpheresTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(SpheresTheme.background)
                )

            // AI Suggestion
            if isLoadingSuggestion {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("AI is analyzing...")
                        .font(.system(size: 12))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
            } else if let suggested = suggestedSphere {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(SpheresTheme.accent)
                    Text("AI suggests:")
                        .font(.system(size: 12))
                        .foregroundColor(SpheresTheme.textTertiary)
                    Circle()
                        .fill(suggested.color)
                        .frame(width: 8, height: 8)
                    Text(suggested.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(suggested.color)
                }
            }

            // Sphere selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Assign to Sphere")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(spheres) { sphere in
                        Button(action: { selectedSphere = sphere }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(sphere.color)
                                    .frame(width: 12, height: 12)
                                Text(sphere.name)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                if suggestedSphere?.id == sphere.id && selectedSphere?.id != sphere.id {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10))
                                        .foregroundColor(SpheresTheme.accent)
                                }
                            }
                            .foregroundColor(selectedSphere?.id == sphere.id ? .white : SpheresTheme.textPrimary)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedSphere?.id == sphere.id ? sphere.color : SpheresTheme.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(suggestedSphere?.id == sphere.id ? SpheresTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Priority
            VStack(alignment: .leading, spacing: 8) {
                Text("Priority (1 = highest)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { rank in
                        Button(action: { importance = rank }) {
                            Text("\(rank)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(importance == rank ? .white : SpheresTheme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(importance == rank ? (selectedSphere?.color ?? SpheresTheme.accent) : SpheresTheme.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button("Delete") {
                    DataManager.shared.deleteInboxItem(item, modelContext: modelContext)
                    isPresented = false
                }
                .buttonStyle(GhostButtonStyle())

                Spacer()

                Button("Cancel") { isPresented = false }
                    .buttonStyle(GhostButtonStyle())

                Button("Create Loop") {
                    processItem()
                    isPresented = false
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(selectedSphere == nil)
            }
        }
        .padding(24)
        .frame(width: 420, height: 480)
        .background(SpheresTheme.surface)
        .onAppear {
            fetchAISuggestion()
        }
    }

    private func fetchAISuggestion() {
        guard aiService.hasAPIKey else { return }
        isLoadingSuggestion = true
        Task {
            let suggested = await aiService.classifyInboxItem(item.content, spheres: spheres)
            await MainActor.run {
                suggestedSphere = suggested
                if selectedSphere == nil {
                    selectedSphere = suggested
                }
                isLoadingSuggestion = false
            }
        }
    }

    private func processItem() {
        guard let sphere = selectedSphere else { return }
        DataManager.shared.processInboxItem(item, toSphere: sphere, importance: importance, modelContext: modelContext)
    }
}

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
                        // Welcome message if no messages yet
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

                                    // Quick prompts
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

// MARK: - Schedule View
// Now uses SmartScheduleView with Energy Intelligence
struct ScheduleView: View {
    var body: some View {
        SmartScheduleView()
    }
}

// MARK: - Legacy Schedule View (kept for reference)
struct LegacyScheduleView: View {
    @Query(sort: \OpenLoopModel.createdDate) private var allLoops: [OpenLoopModel]
    @Query(sort: \SphereModel.priorityRank) private var spheres: [SphereModel]
    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var aiService = AIService.shared
    @State private var selectedDate = Date()
    @State private var showingTimeBlockSheet = false
    @State private var selectedLoopForBlocking: OpenLoopModel?
    @State private var scheduleSuggestions: [ScheduleSuggestion] = []
    @State private var isLoadingSuggestions = false

    // Track scheduled loop IDs to filter them out
    @AppStorage("scheduledLoopIds") private var scheduledLoopIdsString: String = ""

    private var scheduledLoopIds: Set<String> {
        Set(scheduledLoopIdsString.components(separatedBy: ",").filter { !$0.isEmpty })
    }

    private func markLoopAsScheduled(_ loop: OpenLoopModel) {
        var ids = scheduledLoopIds
        ids.insert(loop.id.uuidString)
        scheduledLoopIdsString = ids.joined(separator: ",")
    }

    private var calendar: Calendar { Calendar.current }

    // Loops that should appear today (due today or high priority) - excluding already scheduled
    private var todaysLoops: [OpenLoopModel] {
        let scheduled = scheduledLoopIds
        return allLoops.filter { loop in
            guard !loop.isCompleted else { return false }
            guard !scheduled.contains(loop.id.uuidString) else { return false }
            if let due = loop.dueDate, calendar.isDate(due, inSameDayAs: selectedDate) {
                return true
            }
            // Also show high priority items
            return loop.importance <= 2
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(SpheresTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text(selectedDate.formatted(date: .complete, time: .omitted))
                            .font(.system(size: 14))
                            .foregroundColor(SpheresTheme.textSecondary)

                        if calendarService.hasGoogleCalendarSync {
                            HStack(spacing: 4) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 10))
                                Text("Google synced")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                // Date navigation
                HStack(spacing: 8) {
                    Button(action: { moveDate(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)

                    Button("Today") {
                        selectedDate = Date()
                    }
                    .buttonStyle(GhostButtonStyle())

                    Button(action: { moveDate(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
            .padding(.bottom, 0)

            // Calendar authorization prompt
            if !calendarService.hasAccess {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(SpheresTheme.textTertiary)

                    Text("Calendar access required")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(SpheresTheme.textPrimary)

                    Text("Grant access to see your calendar events and create time blocks for your loops.")
                        .font(.system(size: 13))
                        .foregroundColor(SpheresTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)

                    Button("Grant Calendar Access") {
                        Task {
                            await calendarService.requestAccess()
                        }
                    }
                    .buttonStyle(AccentButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    // Timeline view
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                TimelineRow(
                                    hour: hour,
                                    date: selectedDate,
                                    events: eventsForHour(hour),
                                    calendarService: calendarService
                                )
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)

                    // Right sidebar - loops to schedule
                    VStack(alignment: .leading, spacing: 16) {
                        // AI Scheduling Suggestions
                        if !scheduleSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10))
                                        .foregroundColor(SpheresTheme.accent)
                                    Text("SUGGESTED TIME BLOCKS")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(SpheresTheme.textTertiary)
                                        .tracking(1)
                                }

                                ForEach(scheduleSuggestions) { suggestion in
                                    AISuggestionCard(
                                        suggestion: suggestion,
                                        onSchedule: {
                                            selectedLoopForBlocking = suggestion.loop
                                            showingTimeBlockSheet = true
                                        }
                                    )
                                }
                            }

                            Divider()
                                .background(SpheresTheme.textTertiary.opacity(0.3))
                                .padding(.vertical, 4)
                        } else if isLoadingSuggestions {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Getting suggestions...")
                                    .font(.system(size: 11))
                                    .foregroundColor(SpheresTheme.textTertiary)
                            }
                            .padding(.bottom, 8)
                        }

                        Text("LOOPS TO SCHEDULE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .tracking(1)

                        if todaysLoops.isEmpty {
                            Text("No urgent loops for today")
                                .font(.system(size: 12))
                                .foregroundColor(SpheresTheme.textTertiary)
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(todaysLoops) { loop in
                                        ScheduleLoopCard(
                                            loop: loop,
                                            onSchedule: {
                                                selectedLoopForBlocking = loop
                                                showingTimeBlockSheet = true
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(20)
                    .frame(width: 280)
                    .background(SpheresTheme.surface)
                }
            }
        }
        .onAppear {
            calendarService.fetchEventsForDay(selectedDate)
            fetchScheduleSuggestions()
        }
        .onChange(of: selectedDate) { _, newDate in
            calendarService.fetchEventsForDay(newDate)
            fetchScheduleSuggestions()
        }
        .sheet(isPresented: $showingTimeBlockSheet) {
            if let loop = selectedLoopForBlocking {
                TimeBlockSheet(
                    isPresented: $showingTimeBlockSheet,
                    loop: loop,
                    selectedDate: selectedDate,
                    calendarService: calendarService,
                    onScheduled: { markLoopAsScheduled(loop) }
                )
            }
        }
    }

    private func moveDate(by days: Int) {
        if let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func eventsForHour(_ hour: Int) -> [EKEvent] {
        calendarService.events.filter { event in
            let eventHour = calendar.component(.hour, from: event.startDate)
            return eventHour == hour
        }
    }

    private func fetchScheduleSuggestions() {
        isLoadingSuggestions = true
        scheduleSuggestions = []

        let existingEventSummary = calendarService.events.map { event in
            let time = event.startDate.formatted(date: .omitted, time: .shortened)
            let end = event.endDate.formatted(date: .omitted, time: .shortened)
            return "- \(event.title ?? "Untitled") (\(time) - \(end))"
        }

        // Filter out already-scheduled loops
        let scheduled = scheduledLoopIds
        let unscheduledLoops = allLoops.filter { !scheduled.contains($0.id.uuidString) }

        Task {
            let suggestions = await aiService.getSchedulingSuggestions(
                loops: unscheduledLoops,
                existingEvents: existingEventSummary
            )
            await MainActor.run {
                scheduleSuggestions = suggestions
                isLoadingSuggestions = false
            }
        }
    }
}

// AI Suggestion Card for schedule
struct AISuggestionCard: View {
    let suggestion: ScheduleSuggestion
    let onSchedule: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(suggestion.loop.sphere?.color ?? SpheresTheme.accent)
                    .frame(width: 8, height: 8)

                Text(suggestion.loop.content)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(2)

                Spacer()
            }

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(suggestion.suggestedTime)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(SpheresTheme.accent)

                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9))
                    Text("\(suggestion.suggestedDuration)m")
                        .font(.system(size: 10))
                }
                .foregroundColor(SpheresTheme.textTertiary)

                Spacer()

                if isHovered {
                    Button(action: onSchedule) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 10))
                            Text("Schedule")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(TinyIconButtonStyle())
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                Text(suggestion.reason)
                    .font(.system(size: 10))
            }
            .foregroundColor(SpheresTheme.textTertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(SpheresTheme.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .onHover { isHovered = $0 }
    }
}

// Timeline row for each hour
struct TimelineRow: View {
    let hour: Int
    let date: Date
    let events: [EKEvent]
    let calendarService: CalendarService

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        let hourDate = Calendar.current.date(from: components) ?? date
        return formatter.string(from: hourDate)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Time label
            Text(timeString)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(SpheresTheme.textTertiary)
                .frame(width: 50, alignment: .trailing)

            // Hour line and events
            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(SpheresTheme.border)
                    .frame(height: 1)

                if events.isEmpty {
                    Color.clear
                        .frame(height: 50)
                } else {
                    ForEach(events, id: \.eventIdentifier) { event in
                        CalendarEventCard(event: event, calendarService: calendarService)
                    }
                }
            }
        }
        .frame(minHeight: 60)
    }
}

// Calendar event card
struct CalendarEventCard: View {
    let event: EKEvent
    let calendarService: CalendarService
    @State private var isHovered = false
    @State private var showingEditSheet = false

    private var duration: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: event.startDate, to: event.endDate) ?? ""
    }

    var body: some View {
        Button(action: { showingEditSheet = true }) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color(cgColor: event.calendar.cgColor))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title ?? "Untitled")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(event.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10))
                        Text("•")
                        Text(duration)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(SpheresTheme.textTertiary)
                }

                Spacer()

                if isHovered {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(SpheresTheme.textSecondary)
                }

                if calendarService.googleCalendars.contains(where: { $0.calendarIdentifier == event.calendar.calendarIdentifier }) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .sheet(isPresented: $showingEditSheet) {
            EditCalendarEventSheet(
                isPresented: $showingEditSheet,
                event: event,
                calendarService: calendarService
            )
        }
    }
}

// Edit Calendar Event Sheet
struct EditCalendarEventSheet: View {
    @Binding var isPresented: Bool
    let event: EKEvent
    let calendarService: CalendarService
    @State private var title: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var selectedCalendar: EKCalendar?
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Event")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SpheresTheme.textPrimary)

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .padding(6)
                        .background(Circle().fill(SpheresTheme.surface))
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider().background(SpheresTheme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(SpheresTheme.textTertiary)

                        TextField("Event title", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.surface))
                    }

                    // Time
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Start")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(SpheresTheme.textTertiary)

                            DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("End")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(SpheresTheme.textTertiary)

                            DatePicker("", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                    }

                    // Calendar picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(SpheresTheme.textTertiary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(calendarService.calendars, id: \.calendarIdentifier) { cal in
                                    Button(action: { selectedCalendar = cal }) {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color(cgColor: cal.cgColor))
                                                .frame(width: 8, height: 8)
                                            Text(cal.title)
                                                .font(.system(size: 12))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(selectedCalendar?.calendarIdentifier == cal.calendarIdentifier ? SpheresTheme.accent.opacity(0.2) : SpheresTheme.surface)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(selectedCalendar?.calendarIdentifier == cal.calendarIdentifier ? SpheresTheme.accent : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(SpheresTheme.textPrimary)
                                }
                            }
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }

            Divider().background(SpheresTheme.border)

            // Actions
            HStack(spacing: 12) {
                Button(action: { showDeleteConfirm = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                        Text("Delete")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))

                Spacer()

                Button(action: { isPresented = false }) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Button(action: saveChanges) {
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.accent))
            }
            .padding(20)
        }
        .frame(width: 420, height: 480)
        .background(SpheresTheme.background)
        .onAppear {
            title = event.title ?? ""
            startTime = event.startDate
            endTime = event.endDate
            selectedCalendar = event.calendar
        }
        .alert("Delete Event", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteEvent() }
        } message: {
            Text("Are you sure you want to delete this event? This cannot be undone.")
        }
    }

    private func saveChanges() {
        event.title = title
        event.startDate = startTime
        event.endDate = endTime
        if let newCal = selectedCalendar {
            event.calendar = newCal
        }

        do {
            try calendarService.eventStore.save(event, span: .thisEvent)
            calendarService.fetchEventsForDay(startTime)
            isPresented = false
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func deleteEvent() {
        _ = calendarService.deleteEvent(event)
        calendarService.fetchEventsForDay(event.startDate)
        isPresented = false
    }
}

// Loop card in schedule sidebar
struct ScheduleLoopCard: View {
    let loop: OpenLoopModel
    let onSchedule: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(loop.sphere?.color ?? SpheresTheme.accent)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(loop.content)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let mins = loop.estimatedMinutes {
                        Text("\(mins)m")
                            .font(.system(size: 10))
                    }
                    if let due = loop.dueDate {
                        Text("Due: \(due.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 10))
                    }
                }
                .foregroundColor(SpheresTheme.textTertiary)
            }

            Spacer()

            if isHovered {
                Button(action: onSchedule) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(TinyIconButtonStyle())
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
        )
        .onHover { isHovered = $0 }
    }
}

// Time block creation sheet
struct TimeBlockSheet: View {
    @Binding var isPresented: Bool
    let loop: OpenLoopModel
    let selectedDate: Date
    let calendarService: CalendarService
    var onScheduled: (() -> Void)? = nil

    @State private var startTime = Date()
    @State private var duration: Int = 60
    @State private var selectedCalendarId: String?
    @State private var preferGoogle = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Schedule Time Block")
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

            // Loop info
            HStack(spacing: 10) {
                Circle()
                    .fill(loop.sphere?.color ?? SpheresTheme.accent)
                    .frame(width: 12, height: 12)

                Text(loop.content)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SpheresTheme.textPrimary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(SpheresTheme.background)
            )

            // Time picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Time")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }

            // Duration
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                HStack(spacing: 10) {
                    ForEach([15, 30, 60, 90, 120], id: \.self) { mins in
                        Button(action: { duration = mins }) {
                            Text("\(mins)m")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(duration == mins ? .white : SpheresTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(duration == mins ? (loop.sphere?.color ?? SpheresTheme.accent) : SpheresTheme.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Calendar selection
            if calendarService.hasGoogleCalendarSync {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)

                    Toggle(isOn: $preferGoogle) {
                        HStack(spacing: 6) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 14))
                            Text("Add to Google Calendar")
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.switch)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(GhostButtonStyle())

                Spacer()

                Button("Create Time Block") {
                    createTimeBlock()
                    isPresented = false
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 400, height: 420)
        .background(SpheresTheme.surface)
        .onAppear {
            // Set initial start time to next hour
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: selectedDate)
            components.hour = (components.hour ?? 9) + 1
            components.minute = 0
            startTime = calendar.date(from: components) ?? selectedDate

            // Set duration from loop estimate if available
            if let mins = loop.estimatedMinutes {
                duration = mins
            }
        }
    }

    private func createTimeBlock() {
        let success = calendarService.createTimeBlockOnCalendar(
            title: "[\(loop.sphere?.name ?? "Spheres")] \(loop.content)",
            startDate: startTime,
            duration: duration,
            notes: "Created from Spheres app\nPriority: \(loop.importance)",
            preferGoogle: preferGoogle
        )
        calendarService.fetchEventsForDay(selectedDate)
        if success {
            onScheduled?()
        }
    }
}

// MARK: - Proactive AI Scheduling Popup
struct ProactiveSchedulingPopup: View {
    @Binding var isPresented: Bool
    let loop: OpenLoopModel
    let suggestedSlot: CalendarService.FreeSlot
    let reason: String
    var onScheduled: (() -> Void)? = nil
    var onSeeDay: (() -> Void)? = nil
    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var aiService = AIService.shared
    @State private var isScheduling = false
    @State private var showSuccess = false
    @State private var showCalendarPreview = false
    @State private var errorMessage: String?
    @State private var showCustomTimeInput = false
    @State private var customTimeRequest = ""
    @State private var aiMessage = ""
    @State private var isLoadingAI = true
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    if !showCustomTimeInput { isPresented = false }
                }

            VStack(spacing: 0) {
                // Header with AI avatar
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)

                        Image(systemName: "sparkles")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spheres Assistant")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)
                        Text("Just now")
                            .font(.system(size: 11))
                            .foregroundColor(SpheresTheme.textTertiary)
                    }

                    Spacer()

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .padding(8)
                            .background(Circle().fill(SpheresTheme.background))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)

                // Message bubble
                VStack(alignment: .leading, spacing: 16) {
                    if isLoadingAI {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .font(.system(size: 13))
                                .foregroundColor(SpheresTheme.textSecondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text(aiMessage)
                            .font(.system(size: 14))
                            .foregroundColor(SpheresTheme.textPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Mini calendar preview
                    VStack(spacing: 0) {
                        // Calendar header
                        HStack {
                            Text(suggestedSlot.startDate.formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(SpheresTheme.textPrimary)
                            Spacer()
                            Button(action: {
                                if let onSeeDay = onSeeDay {
                                    onSeeDay()
                                } else {
                                    showCalendarPreview.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("See day")
                                        .font(.system(size: 11))
                                    Image(systemName: "calendar")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(SpheresTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(SpheresTheme.surfaceHover)

                        // Time slot
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(loop.sphere?.color ?? SpheresTheme.accent)
                                .frame(width: 4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(loop.content)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(SpheresTheme.textPrimary)
                                    .lineLimit(1)
                                Text(suggestedSlot.displayRange)
                                    .font(.system(size: 11))
                                    .foregroundColor(SpheresTheme.textSecondary)
                            }
                            .padding(.leading, 10)
                            .padding(.vertical, 10)

                            Spacer()

                            if let sphere = loop.sphere {
                                Text(sphere.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(sphere.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(sphere.color.opacity(0.15))
                                    .cornerRadius(4)
                                    .padding(.trailing, 10)
                            }
                        }
                        .background(SpheresTheme.background)

                        // Expanded calendar preview
                        if showCalendarPreview {
                            MiniCalendarPreview(date: suggestedSlot.startDate, calendarService: calendarService)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 10).fill(SpheresTheme.background))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(loop.sphere?.color.opacity(0.3) ?? SpheresTheme.accent.opacity(0.3), lineWidth: 1)
                    )

                    // Custom time input
                    if showCustomTimeInput {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("When works better for you?")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(SpheresTheme.textSecondary)

                            HStack(spacing: 8) {
                                TextField("e.g., tomorrow at 2pm, Friday morning...", text: $customTimeRequest)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.background))
                                    .focused($isInputFocused)

                                Button(action: processCustomTime) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(SpheresTheme.accent)
                                }
                                .buttonStyle(.plain)
                                .disabled(customTimeRequest.isEmpty)
                            }
                        }
                        .padding(.top, 4)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                Divider().background(SpheresTheme.border)

                // Actions - All three on same line
                HStack(spacing: 10) {
                    // Yes button
                    Button(action: scheduleIt) {
                        HStack(spacing: 4) {
                            if isScheduling {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.white)
                            } else if showSuccess {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                            } else {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 11))
                            }
                            Text(showSuccess ? "Done!" : "Yes")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(RoundedRectangle(cornerRadius: 8).fill(
                        showSuccess ? Color.green : (loop.sphere?.color ?? SpheresTheme.accent)
                    ))
                    .disabled(isScheduling || showSuccess)

                    // Different time button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCustomTimeInput.toggle()
                            if showCustomTimeInput {
                                isInputFocused = true
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text("Different time")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(SpheresTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.surfaceHover))

                    // Not now button
                    Button(action: { isPresented = false }) {
                        Text("Not now")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SpheresTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.surfaceHover))
                }
                .padding(20)
            }
            .frame(width: 460)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.08, green: 0.08, blue: 0.10)))
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
        }
        .onAppear {
            // Request calendar access if needed
            if !calendarService.hasAccess {
                Task {
                    _ = await calendarService.requestAccess()
                }
            }
            // Generate AI message
            generateAIMessage()
        }
    }

    private func generateAIMessage() {
        Task {
            let message = await aiService.generateSchedulingSuggestion(
                loop: loop,
                suggestedTime: suggestedSlot.startDate,
                duration: suggestedSlot.duration
            )
            await MainActor.run {
                aiMessage = message
                isLoadingAI = false
            }
        }
    }

    private func processCustomTime() {
        // For now, just close and let user know
        // In future, AI can parse and reschedule
        isPresented = false
    }

    private func scheduleIt() {
        isScheduling = true
        errorMessage = nil

        // Check calendar access
        guard calendarService.hasAccess else {
            Task {
                let granted = await calendarService.requestAccess()
                await MainActor.run {
                    isScheduling = false
                    if granted {
                        scheduleIt() // Retry
                    } else {
                        errorMessage = "Calendar access required. Please grant access in System Settings."
                    }
                }
            }
            return
        }

        let duration = loop.estimatedMinutes ?? suggestedSlot.duration
        let success = calendarService.createTimeBlockForLoop(
            loop: loop,
            startDate: suggestedSlot.startDate,
            duration: duration
        )

        isScheduling = false
        if success {
            showSuccess = true
            onScheduled?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isPresented = false
            }
        } else {
            errorMessage = "Couldn't create calendar event. Please check calendar permissions."
        }
    }
}

// Mini calendar preview showing surrounding events
struct MiniCalendarPreview: View {
    let date: Date
    let calendarService: CalendarService

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(SpheresTheme.border)

            if calendarService.events.isEmpty {
                Text("No other events this day")
                    .font(.system(size: 11))
                    .foregroundColor(SpheresTheme.textTertiary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 1) {
                    ForEach(calendarService.events.prefix(3), id: \.eventIdentifier) { event in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(cgColor: event.calendar.cgColor))
                                .frame(width: 6, height: 6)
                            Text(event.title ?? "Untitled")
                                .font(.system(size: 11))
                                .foregroundColor(SpheresTheme.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text(event.startDate.formatted(.dateTime.hour().minute()))
                                .font(.system(size: 10))
                                .foregroundColor(SpheresTheme.textTertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }

                    if calendarService.events.count > 3 {
                        Text("+ \(calendarService.events.count - 3) more")
                            .font(.system(size: 10))
                            .foregroundColor(SpheresTheme.textTertiary)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .onAppear {
            calendarService.fetchEventsForDay(date)
        }
    }
}

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

// MARK: - Add Sphere Sheet
struct AddSphereSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var sphereDescription = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor = Color.purple
    @State private var priorityRank = 3
    @State private var selectedCategory = 0
    @State private var selectedIconStyle: IconLibrary.IconStyle = .filled
    @State private var showingImagePicker = false

    let colors: [Color] = [.purple, .blue, .green, .orange, .red, .pink, .yellow, .cyan, .mint, .indigo, .teal, .brown]

    var currentIcons: [(String, [String])] {
        IconLibrary.icons(for: selectedIconStyle)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header
                HStack {
                    Text("Create New Sphere")
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

                // Preview
                ZStack {
                    Circle()
                        .fill(selectedColor.opacity(0.15))
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [selectedColor, selectedColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: selectedColor.opacity(0.4), radius: 10, x: 0, y: 4)

                    Image(systemName: selectedIcon)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }

                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)

                    TextField("e.g., Health, Career, Family", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SpheresTheme.background)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpheresTheme.border))
                        )
                }

                // Icon Style Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon Style")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(IconLibrary.IconStyle.allCases, id: \.self) { style in
                                Button(action: { selectedIconStyle = style }) {
                                    VStack(spacing: 4) {
                                        Text(style.rawValue)
                                            .font(.system(size: 11, weight: .medium))
                                        Text(style.description)
                                            .font(.system(size: 8))
                                            .foregroundColor(selectedIconStyle == style ? .white.opacity(0.7) : SpheresTheme.textTertiary)
                                    }
                                    .foregroundColor(selectedIconStyle == style ? .white : SpheresTheme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIconStyle == style ? SpheresTheme.accent : SpheresTheme.surface)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Icon Category & Grid
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Icon")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SpheresTheme.textSecondary)

                        Spacer()

                        Button(action: { showingImagePicker = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.system(size: 10))
                                Text("Upload custom")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(SpheresTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    // Category tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(currentIcons.enumerated()), id: \.0) { index, category in
                                Button(action: { selectedCategory = index }) {
                                    Text(category.0)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(selectedCategory == index ? .white : SpheresTheme.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(selectedCategory == index ? SpheresTheme.accent : SpheresTheme.surface)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Icons grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(currentIcons[min(selectedCategory, currentIcons.count - 1)].1, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(selectedIcon == icon ? .white : SpheresTheme.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon ? selectedColor : SpheresTheme.surface)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

            // Color
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(colors, id: \.self) { color in
                        Button(action: { selectedColor = color }) {
                            Circle()
                                .fill(color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                                        .padding(2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Priority
            VStack(alignment: .leading, spacing: 8) {
                Text("Sphere Priority")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { rank in
                        Button(action: { priorityRank = rank }) {
                            Text("\(rank)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(priorityRank == rank ? .white : SpheresTheme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(priorityRank == rank ? SpheresTheme.accent : SpheresTheme.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Text("1 = most important")
                        .font(.system(size: 10))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
            }

                // Actions
                HStack(spacing: 12) {
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(GhostButtonStyle())

                    Button("Create Sphere") {
                        createSphere()
                        isPresented = false
                    }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(name.isEmpty)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(width: 520, height: 620)
        .background(SpheresTheme.surface)
    }

    private func createSphere() {
        let _ = DataManager.shared.createSphere(
            name: name,
            icon: selectedIcon,
            color: selectedColor,
            description: sphereDescription,
            priorityRank: priorityRank,
            customImageData: nil,
            modelContext: modelContext
        )
    }
}

// MARK: - Edit Sphere Sheet
struct EditSphereSheet: View {
    let sphere: SphereModel
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var sphereDescription: String = ""
    @State private var selectedIcon: String = ""
    @State private var selectedColor: Color = .purple
    @State private var priorityRank: Int = 3
    @State private var selectedCategory = 0
    @State private var selectedIconStyle: IconLibrary.IconStyle = .filled

    let colors: [Color] = [.purple, .blue, .green, .orange, .red, .pink, .yellow, .cyan, .mint, .indigo, .teal, .brown]

    var currentIcons: [(String, [String])] {
        IconLibrary.icons(for: selectedIconStyle)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header
                HStack {
                    Text("Edit Sphere")
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

                // Preview
                ZStack {
                    Circle()
                        .fill(selectedColor.opacity(0.15))
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [selectedColor, selectedColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: selectedColor.opacity(0.4), radius: 10, x: 0, y: 4)

                    Image(systemName: selectedIcon)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }

                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)

                    TextField("e.g., Health, Career, Family", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SpheresTheme.background)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpheresTheme.border))
                        )
                }

                // Description
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description (optional)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)

                    TextField("Brief description", text: $sphereDescription)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SpheresTheme.background)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpheresTheme.border))
                        )
                }

                // Color
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(colors, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                ZStack {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 32, height: 32)
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Icon Grid (simplified)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(currentIcons.enumerated()), id: \.0) { index, category in
                                Button(action: { selectedCategory = index }) {
                                    Text(category.0)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(selectedCategory == index ? .white : SpheresTheme.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(selectedCategory == index ? SpheresTheme.accent : SpheresTheme.surface)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(currentIcons[safe: selectedCategory]?.1 ?? [], id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedIcon == icon ? selectedColor : SpheresTheme.surface)
                                        .frame(width: 40, height: 40)
                                    Image(systemName: icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedIcon == icon ? .white : SpheresTheme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: 120)
                }

                // Priority
                VStack(alignment: .leading, spacing: 8) {
                    Text("Priority Rank")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { rank in
                            Button(action: { priorityRank = rank }) {
                                Text("\(rank)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(priorityRank == rank ? .white : SpheresTheme.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(priorityRank == rank ? selectedColor : SpheresTheme.surface)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Text(priorityRank == 1 ? "Highest" : priorityRank == 5 ? "Lowest" : "")
                            .font(.system(size: 11))
                            .foregroundColor(SpheresTheme.textTertiary)
                    }
                }

                // Actions
                HStack(spacing: 12) {
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(GhostButtonStyle())

                    Button("Save Changes") {
                        saveSphere()
                        isPresented = false
                    }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(name.isEmpty)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(width: 520, height: 580)
        .background(SpheresTheme.surface)
        .onAppear {
            name = sphere.name
            sphereDescription = sphere.sphereDescription
            selectedIcon = sphere.icon
            selectedColor = sphere.color
            priorityRank = sphere.priorityRank
        }
    }

    private func saveSphere() {
        sphere.name = name
        sphere.sphereDescription = sphereDescription
        sphere.icon = selectedIcon
        sphere.setColor(selectedColor)
        sphere.priorityRank = priorityRank
        try? modelContext.save()
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Button Styles
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.accent))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(SpheresTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).stroke(SpheresTheme.border))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct SmallAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(SpheresTheme.accent))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SmallGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(SpheresTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).stroke(SpheresTheme.border))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(SpheresTheme.textSecondary)
            .frame(width: 32, height: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.surface))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct TinyIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(SpheresTheme.textSecondary)
            .frame(width: 24, height: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(SpheresTheme.surface))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Add Loop Sheet
struct AddLoopSheet: View {
    @Binding var isPresented: Bool
    let sphere: SphereModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultPriority") private var defaultPriority: Int = 3
    @State private var content = ""
    @State private var importance = 3
    @State private var estimatedMinutes: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add Open Loop")
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

            // Sphere indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(sphere.color)
                    .frame(width: 12, height: 12)
                Text("Adding to \(sphere.name)")
                    .font(.system(size: 13))
                    .foregroundColor(SpheresTheme.textSecondary)
                Spacer()
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text("What's on your mind?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                TextField("e.g., Call the dentist, Review project proposal", text: $content)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(SpheresTheme.background)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpheresTheme.border))
                    )
            }

            // Priority
            VStack(alignment: .leading, spacing: 8) {
                Text("Priority (1 = highest)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { rank in
                        Button(action: { importance = rank }) {
                            Text("\(rank)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(importance == rank ? .white : SpheresTheme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(importance == rank ? sphere.color : SpheresTheme.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }

            // Estimated time (optional)
            VStack(alignment: .leading, spacing: 6) {
                Text("Estimated time (optional)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                HStack {
                    TextField("e.g., 30", text: $estimatedMinutes)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .frame(width: 80)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SpheresTheme.background)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpheresTheme.border))
                        )
                    Text("minutes")
                        .font(.system(size: 13))
                        .foregroundColor(SpheresTheme.textTertiary)
                    Spacer()
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(GhostButtonStyle())

                Button("Add Loop") {
                    createLoop()
                    isPresented = false
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(content.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 380)
        .background(SpheresTheme.surface)
        .onAppear { importance = defaultPriority }
    }

    private func createLoop() {
        let minutes = Int(estimatedMinutes)
        let _ = DataManager.shared.createLoop(
            content: content,
            sphere: sphere,
            importance: importance,
            progress: 0.0,
            estimatedMinutes: minutes,
            modelContext: modelContext
        )
    }
}

// MARK: - Edit Loop Sheet
struct EditLoopSheet: View {
    @Binding var isPresented: Bool
    let loop: OpenLoopModel
    let allSpheres: [SphereModel]
    @Environment(\.modelContext) private var modelContext

    @State private var content: String = ""
    @State private var importance: Int = 3
    @State private var progress: Double = 0.0
    @State private var estimatedMinutes: String = ""
    @State private var selectedSphere: SphereModel?
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var isHabit: Bool = false
    @State private var isRecurring: Bool = false
    @State private var recurrenceType: RecurrenceType = .none
    @State private var recurrenceInterval: Int = 1

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Edit Loop")
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

            ScrollView {
                VStack(spacing: 20) {
                    // Content
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Content")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SpheresTheme.textSecondary)

                        TextField("What's on your mind?", text: $content)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(SpheresTheme.background)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpheresTheme.border))
                            )
                    }

                    // Sphere picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sphere")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SpheresTheme.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(allSpheres) { sphere in
                                    Button(action: { selectedSphere = sphere }) {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(sphere.color)
                                                .frame(width: 10, height: 10)
                                            Text(sphere.name)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(selectedSphere?.id == sphere.id ? .white : SpheresTheme.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedSphere?.id == sphere.id ? sphere.color : SpheresTheme.surface)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Priority
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority (1 = highest)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SpheresTheme.textSecondary)

                        HStack(spacing: 10) {
                            ForEach(1...5, id: \.self) { rank in
                                Button(action: { importance = rank }) {
                                    Text("\(rank)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(importance == rank ? .white : SpheresTheme.textSecondary)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(importance == rank ? (selectedSphere?.color ?? SpheresTheme.accent) : SpheresTheme.surface)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }

                    // Progress
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(SpheresTheme.textSecondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(selectedSphere?.color ?? SpheresTheme.accent)
                        }

                        Slider(value: $progress, in: 0...1, step: 0.05)
                            .tint(selectedSphere?.color ?? SpheresTheme.accent)
                    }

                    // Estimated time
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Estimated time (optional)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SpheresTheme.textSecondary)

                        HStack {
                            TextField("e.g., 30", text: $estimatedMinutes)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .frame(width: 80)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(SpheresTheme.background)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpheresTheme.border))
                                )
                            Text("minutes")
                                .font(.system(size: 13))
                                .foregroundColor(SpheresTheme.textTertiary)
                            Spacer()
                        }
                    }

                    // Due date
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Due date")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(SpheresTheme.textSecondary)

                            Spacer()

                            Toggle("", isOn: $hasDueDate)
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                        }

                        if hasDueDate {
                            DatePicker("", selection: $dueDate, displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .frame(maxHeight: 280)
                        }
                    }

                    // Habit toggle
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recurring habit")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(SpheresTheme.textSecondary)
                                Text("Track streaks for daily tasks")
                                    .font(.system(size: 10))
                                    .foregroundColor(SpheresTheme.textTertiary)
                            }

                            Spacer()

                            Toggle("", isOn: $isHabit)
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                        }

                        if isHabit && loop.currentStreak > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                                Text("\(loop.currentStreak) day streak")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // Recurring task
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recurring task")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(SpheresTheme.textSecondary)
                                Text("Auto-create next occurrence when completed")
                                    .font(.system(size: 10))
                                    .foregroundColor(SpheresTheme.textTertiary)
                            }

                            Spacer()

                            Toggle("", isOn: $isRecurring)
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                        }

                        if isRecurring {
                            VStack(alignment: .leading, spacing: 10) {
                                // Recurrence type picker
                                HStack(spacing: 8) {
                                    ForEach([RecurrenceType.daily, .weekly, .monthly], id: \.self) { type in
                                        Button(action: { recurrenceType = type }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: type.icon)
                                                    .font(.system(size: 10))
                                                Text(type.displayName)
                                                    .font(.system(size: 11, weight: .medium))
                                            }
                                            .foregroundColor(recurrenceType == type ? .white : SpheresTheme.textSecondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(recurrenceType == type ? (selectedSphere?.color ?? SpheresTheme.accent) : SpheresTheme.surface)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                // Interval picker
                                HStack(spacing: 8) {
                                    Text("Every")
                                        .font(.system(size: 12))
                                        .foregroundColor(SpheresTheme.textSecondary)

                                    Stepper(value: $recurrenceInterval, in: 1...30) {
                                        Text("\(recurrenceInterval)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(SpheresTheme.textPrimary)
                                    }
                                    .frame(width: 100)

                                    Text(intervalLabel)
                                        .font(.system(size: 12))
                                        .foregroundColor(SpheresTheme.textSecondary)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(GhostButtonStyle())

                Button("Save Changes") {
                    saveChanges()
                    isPresented = false
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(content.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420, height: sheetHeight)
        .background(SpheresTheme.surface)
        .onAppear {
            content = loop.content
            importance = loop.importance
            progress = loop.progress
            selectedSphere = loop.sphere
            isHabit = loop.isHabit
            isRecurring = loop.isRecurring
            recurrenceType = loop.recurrenceTypeEnum
            recurrenceInterval = loop.recurrenceInterval
            if let mins = loop.estimatedMinutes {
                estimatedMinutes = "\(mins)"
            }
            if let date = loop.dueDate {
                hasDueDate = true
                dueDate = date
            }
        }
    }

    private var sheetHeight: CGFloat {
        var height: CGFloat = 520
        if hasDueDate { height += 160 }
        if isRecurring { height += 80 }
        return height
    }

    private var intervalLabel: String {
        switch recurrenceType {
        case .daily: return recurrenceInterval == 1 ? "day" : "days"
        case .weekly: return recurrenceInterval == 1 ? "week" : "weeks"
        case .monthly: return recurrenceInterval == 1 ? "month" : "months"
        default: return "days"
        }
    }

    private func saveChanges() {
        DataManager.shared.updateLoop(
            loop,
            content: content,
            sphere: selectedSphere,
            importance: importance,
            progress: progress,
            estimatedMinutes: Int(estimatedMinutes),
            dueDate: hasDueDate ? dueDate : nil,
            clearDueDate: !hasDueDate,
            modelContext: modelContext
        )
        // Handle habit toggle separately
        if loop.isHabit != isHabit {
            DataManager.shared.toggleHabit(loop, modelContext: modelContext)
        }
        // Handle recurring task settings
        if loop.isRecurring != isRecurring || loop.recurrenceTypeEnum != recurrenceType || loop.recurrenceInterval != recurrenceInterval {
            DataManager.shared.updateRecurrence(
                loop,
                isRecurring: isRecurring,
                recurrenceType: isRecurring ? recurrenceType : .none,
                interval: recurrenceInterval,
                modelContext: modelContext
            )
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

