//
//  SphereDetailView.swift
//  Spheres - Smart Life Manager
//
//  Sphere full page view, detail sheet, loop cards, add/edit loop sheets.
//

import SwiftUI
import SwiftData

// MARK: - Modern Sphere Action Menu
struct SphereActionMenu: View {
    let sphere: SphereModel
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var editHovered = false
    @State private var deleteHovered = false

    var body: some View {
        VStack(spacing: 2) {
            Button(action: onEdit) {
                HStack(spacing: 10) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(editHovered ? sphere.color : SpheresTheme.textSecondary)
                        .frame(width: 20)
                    Text("Edit Sphere")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(editHovered ? SpheresTheme.textPrimary : SpheresTheme.textSecondary)
                    Spacer()
                    Text("\u{2318}E")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(SpheresTheme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(editHovered ? SpheresTheme.surfaceHover : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { editHovered = h } }

            Rectangle()
                .fill(SpheresTheme.border)
                .frame(height: 0.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            Button(action: onDelete) {
                HStack(spacing: 10) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(deleteHovered ? .red : SpheresTheme.textTertiary)
                        .frame(width: 20)
                    Text("Delete Sphere")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(deleteHovered ? .red : SpheresTheme.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(deleteHovered ? Color.red.opacity(0.1) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { deleteHovered = h } }
        }
        .padding(6)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SpheresTheme.border.opacity(0.5), lineWidth: 0.5)
                )
        )
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
    @State private var showingSphereMenu = false
    @State private var menuButtonHovered = false
    @State private var headerHovered = false
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

                Button(action: { showingSphereMenu.toggle() }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(menuButtonHovered ? SpheresTheme.textPrimary : SpheresTheme.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(menuButtonHovered ? SpheresTheme.surfaceHover : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { menuButtonHovered = h } }
                .popover(isPresented: $showingSphereMenu, arrowEdge: .top) {
                    SphereActionMenu(
                        sphere: sphere,
                        onEdit: {
                            showingSphereMenu = false
                            showingEditSphere = true
                        },
                        onDelete: {
                            showingSphereMenu = false
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Sphere Header
            HStack(spacing: 20) {
                // Clickable sphere info — opens edit sheet
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
                        HStack(spacing: 8) {
                            Text(sphere.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SpheresTheme.textPrimary)

                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundColor(SpheresTheme.textTertiary.opacity(headerHovered ? 0.8 : 0.3))
                        }

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
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(headerHovered ? SpheresTheme.surface : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(headerHovered ? sphere.color.opacity(0.2) : Color.clear, lineWidth: 1)
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture { showingEditSphere = true }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) { headerHovered = hovering }
                }

                Spacer()

                Button(action: { showingAddLoop = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add Loop")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(SpheresTheme.accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(SpheresTheme.accent.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
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
        for loop in loops {
            modelContext.delete(loop)
        }
        modelContext.delete(sphere)
        try? modelContext.save()
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

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(loops) { loop in
                        DetailLoopCard(loop: loop, sphereColor: sphere.color, allSpheres: allSpheres)
                    }

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
    @State private var timerTick = false
    @State private var swipeOffset: CGFloat = 0
    @State private var showingSwipeDelete = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .trailing) {
            // Swipe-to-delete background
            if swipeOffset < -30 {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            swipeOffset = 0
                        }
                        deleteLoop()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16))
                            Text("Delete")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxHeight: .infinity)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.85))
                )
                .transition(.opacity)
            }

            // Main card content
            mainCardContent
                .offset(x: swipeOffset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            if value.translation.width < 0 {
                                swipeOffset = max(value.translation.width, -80)
                            } else if swipeOffset < 0 {
                                swipeOffset = min(0, swipeOffset + value.translation.width)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if swipeOffset < -45 {
                                    swipeOffset = -75
                                } else {
                                    swipeOffset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }

    private var mainCardContent: some View {
        HStack(spacing: 12) {
            // Completion circle
            Button(action: { toggleComplete() }) {
                ZStack {
                    Circle()
                        .stroke(sphereColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if loop.isCompleted {
                        Circle()
                            .fill(sphereColor)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    } else if loop.progress > 0 {
                        Circle()
                            .trim(from: 0, to: loop.progress)
                            .stroke(sphereColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 22, height: 22)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(loop.content)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(loop.isCompleted ? SpheresTheme.textTertiary : SpheresTheme.textPrimary)
                    .strikethrough(loop.isCompleted)

                HStack(spacing: 10) {
                    // Priority dots (more filled = higher priority)
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { level in
                            Circle()
                                .fill(level <= (6 - loop.importance) ? sphereColor : SpheresTheme.border)
                                .frame(width: 4, height: 4)
                        }
                    }

                    // Progress percentage (only when in progress)
                    if loop.progress > 0 && !loop.isCompleted {
                        Text("\(Int(loop.progress * 100))%")
                            .font(.system(size: 11, weight: .medium))
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

                    if loop.timeSpentSeconds > 0 || loop.isTimerRunning {
                        HStack(spacing: 4) {
                            Image(systemName: loop.isTimerRunning ? "timer" : "hourglass")
                                .font(.system(size: 10))
                            Text(formatTimeSpent(loop.totalTimeSpent))
                                .font(.system(size: 11, weight: loop.isTimerRunning ? .semibold : .regular))
                                .id(timerTick)
                        }
                        .foregroundColor(loop.isTimerRunning ? sphereColor : SpheresTheme.textTertiary)
                    }

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

// MARK: - Add Loop Sheet
struct AddLoopSheet: View {
    @Binding var isPresented: Bool
    let sphere: SphereModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultPriority") private var defaultPriority: Int = 3
    @StateObject private var aiService = AIService.shared
    @State private var content = ""
    @State private var importance = 3
    @State private var estimatedMinutes: String = ""
    @State private var isProcessing = false
    @State private var aiDidProcess = false

    var body: some View {
        VStack(spacing: 20) {
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

            HStack(spacing: 8) {
                Circle()
                    .fill(sphere.color)
                    .frame(width: 12, height: 12)
                Text("Adding to \(sphere.name)")
                    .font(.system(size: 13))
                    .foregroundColor(SpheresTheme.textSecondary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Describe the task — include urgency and time needed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                TextField("e.g., \"Review proposal by Friday, ~45 min, high priority\"", text: $content)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(SpheresTheme.background)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpheresTheme.border))
                    )
                    .onSubmit {
                        if !content.isEmpty { Task { await processAndCreate() } }
                    }
            }

            // AI-determined fields (editable)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("Priority")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)
                    if aiDidProcess {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundColor(SpheresTheme.accent.opacity(0.7))
                    }
                }

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

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("Estimated time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SpheresTheme.textSecondary)
                    if aiDidProcess {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundColor(SpheresTheme.accent.opacity(0.7))
                    }
                }

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

            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.textSecondary.opacity(0.08)))
                    .buttonStyle(.plain)

                Button {
                    Task { await processAndCreate() }
                } label: {
                    HStack(spacing: 6) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                        }
                        Text(isProcessing ? "Processing..." : "Add Loop")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .disabled(content.isEmpty || isProcessing)
            }
        }
        .padding(28)
        .frame(width: 420, height: 420)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(SpheresTheme.border, lineWidth: 0.5)
                )
        )
        .onAppear { importance = defaultPriority }
    }

    private func processAndCreate() async {
        isProcessing = true

        // Try AI processing to extract priority + time
        if aiService.hasAPIKey {
            let result = await aiService.processOpenLoop(content, spheres: [sphere])
            if let result = result {
                importance = result.priority
                if let mins = result.estimatedMinutes {
                    estimatedMinutes = "\(mins)"
                }
                content = result.content // Use cleaned-up task name
                aiDidProcess = true
            }
        }

        // Create the loop
        let minutes = Int(estimatedMinutes)
        let _ = DataManager.shared.createLoop(
            content: content,
            sphere: sphere,
            importance: importance,
            progress: 0.0,
            estimatedMinutes: minutes,
            modelContext: modelContext
        )

        isProcessing = false
        isPresented = false
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

            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.textSecondary.opacity(0.08)))
                    .buttonStyle(.plain)

                Button("Save Changes") {
                    saveChanges()
                    isPresented = false
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(SpheresTheme.accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.accent.opacity(0.12)))
                .buttonStyle(.plain)
                .disabled(content.isEmpty)
            }
        }
        .padding(28)
        .frame(width: 420, height: sheetHeight)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(SpheresTheme.border, lineWidth: 0.5)
                )
        )
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
        if loop.isHabit != isHabit {
            DataManager.shared.toggleHabit(loop, modelContext: modelContext)
        }
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
