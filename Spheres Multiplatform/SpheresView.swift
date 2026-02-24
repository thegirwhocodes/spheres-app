//
//  SpheresView.swift
//  Spheres - Smart Life Manager
//
//  Spheres grid view, compact cards, add/edit sphere sheets.
//

import SwiftUI
import SwiftData

// MARK: - Spheres View (Clustered Bubbles)
struct SpheresView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\SphereModel.priorityRank), SortDescriptor(\SphereModel.createdDate)]) private var spheres: [SphereModel]

    @State private var showingAddSphere = false
    @State private var quickViewSphere: SphereModel? = nil
    @State private var selectedSphereForFullView: SphereModel? = nil
    @State private var editingSphereFromGrid: SphereModel? = nil
    @State private var hasSeededData = false
    @State private var draggingSphere: SphereModel? = nil
    @State private var sphereToDelete: SphereModel? = nil
    @State private var showingDeleteConfirmation = false
    @State private var hoveredSphereId: UUID? = nil
    @State private var showingCardView = false
    @State private var swipeDragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            if let sphere = selectedSphereForFullView {
                SphereFullPageView(
                    sphere: sphere,
                    loops: (sphere.loops ?? []).sorted { $0.importance < $1.importance },
                    allSpheres: spheres,
                    onBack: { selectedSphereForFullView = nil }
                )
                .transition(.move(edge: .trailing))
            } else {
                VStack(spacing: 0) {
                    // Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Life")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SpheresTheme.textPrimary)

                            HStack(spacing: 8) {
                                Text("\(spheres.count) spheres")
                                    .font(.system(size: 14))
                                    .foregroundColor(SpheresTheme.textSecondary)

                                // Page indicator dots
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(showingCardView ? SpheresTheme.textTertiary : SpheresTheme.accent)
                                        .frame(width: 6, height: 6)
                                    Circle()
                                        .fill(showingCardView ? SpheresTheme.accent : SpheresTheme.textTertiary)
                                        .frame(width: 6, height: 6)
                                }
                                .animation(.easeInOut(duration: 0.2), value: showingCardView)
                            }
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

                    // Swipeable Content
                    GeometryReader { outerGeo in
                        HStack(spacing: 0) {
                            // Page 1: Bouncy Balls
                            bubblesPage
                                .frame(width: outerGeo.size.width)

                            // Page 2: Card Grid
                            cardGridPage
                                .frame(width: outerGeo.size.width)
                        }
                        .offset(x: showingCardView ? -outerGeo.size.width + swipeDragOffset : swipeDragOffset)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingCardView)
                        .gesture(
                            DragGesture(minimumDistance: 30)
                                .onChanged { value in
                                    swipeDragOffset = value.translation.width
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = 80
                                    if value.translation.width < -threshold && !showingCardView {
                                        showingCardView = true
                                    } else if value.translation.width > threshold && showingCardView {
                                        showingCardView = false
                                    }
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        swipeDragOffset = 0
                                    }
                                }
                        )
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
        .sheet(item: $editingSphereFromGrid) { sphere in
            EditSphereSheet(sphere: sphere, isPresented: Binding(
                get: { editingSphereFromGrid != nil },
                set: { if !$0 { editingSphereFromGrid = nil } }
            ))
        }
        .alert("Delete Sphere?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { sphereToDelete = nil }
            Button("Delete", role: .destructive) {
                if let sphere = sphereToDelete {
                    deleteSphereFromGrid(sphere)
                }
            }
        } message: {
            Text("This will permanently delete \"\(sphereToDelete?.name ?? "")\" and all its loops.")
        }
    }

    // MARK: - Bubbles Page
    private var bubblesPage: some View {
        ScrollView {
            GeometryReader { geo in
                let packed = packCircles(spheres: spheres, containerWidth: geo.size.width)

                ZStack {
                    ForEach(Array(spheres.enumerated()), id: \.element.id) { index, sphere in
                        let pos = index < packed.positions.count ? packed.positions[index] : .zero
                        let size = ballDiameter(for: sphere.priorityRank)

                        BouncySphereOrb(
                            sphere: sphere,
                            loops: (sphere.loops ?? []).sorted { $0.importance < $1.importance },
                            ballSize: size,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedSphereForFullView = sphere
                                }
                            },
                            onQuickView: { quickViewSphere = sphere },
                            onEdit: { editingSphereFromGrid = sphere },
                            onDelete: {
                                sphereToDelete = sphere
                                showingDeleteConfirmation = true
                            },
                            hoveredSphereId: $hoveredSphereId
                        )
                        .position(x: pos.x, y: pos.y)
                        .zIndex(hoveredSphereId == sphere.id ? 100 : Double(10 - sphere.priorityRank))
                        .opacity(draggingSphere?.id == sphere.id ? 0.4 : 1.0)
                        .draggable(sphere.id.uuidString) {
                            ZStack {
                                Circle()
                                    .fill(sphere.color.opacity(0.85))
                                    .frame(width: 50, height: 50)
                                Image(systemName: sphere.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                            .onAppear { draggingSphere = sphere }
                        }
                        .dropDestination(for: String.self) { items, _ in
                            guard let droppedId = items.first,
                                  let droppedUUID = UUID(uuidString: droppedId),
                                  let sourceSphere = spheres.first(where: { $0.id == droppedUUID }),
                                  sourceSphere.id != sphere.id else {
                                return false
                            }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                reorderSpheres(from: sourceSphere, to: sphere)
                            }
                            draggingSphere = nil
                            return true
                        }
                    }
                }
                .frame(width: geo.size.width, height: packed.totalHeight)
            }
            .frame(minHeight: packCircles(spheres: spheres, containerWidth: 700).totalHeight)
        }
    }

    // MARK: - Card Grid Page
    private var cardGridPage: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                ForEach(spheres) { sphere in
                    RoundedSphereCard(
                        sphere: sphere,
                        loops: (sphere.loops ?? []).sorted { $0.importance < $1.importance },
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedSphereForFullView = sphere
                            }
                        },
                        onQuickView: { quickViewSphere = sphere },
                        onEdit: { editingSphereFromGrid = sphere },
                        onDelete: {
                            sphereToDelete = sphere
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Ball Sizing (smaller, varied)
    private func ballDiameter(for rank: Int) -> CGFloat {
        switch rank {
        case 1: return 130
        case 2: return 110
        case 3: return 95
        case 4: return 80
        default: return 70
        }
    }

    // MARK: - Organic Circle Packing
    private struct PackResult {
        let positions: [CGPoint]
        let totalHeight: CGFloat
    }

    private func packCircles(spheres: [SphereModel], containerWidth: CGFloat) -> PackResult {
        guard !spheres.isEmpty else { return PackResult(positions: [], totalHeight: 300) }

        let gap: CGFloat = 14
        var placed: [(center: CGPoint, radius: CGFloat)] = []
        var positions: [CGPoint] = []
        let centerX = containerWidth / 2

        for (index, sphere) in spheres.enumerated() {
            let r = ballDiameter(for: sphere.priorityRank) / 2
            let expandedR = r + gap / 2  // half-gap per side

            if placed.isEmpty {
                // First ball: center, near top
                let pos = CGPoint(x: centerX, y: r + 40)
                placed.append((center: pos, radius: expandedR))
                positions.append(pos)
                continue
            }

            // Try placing touching each existing ball at various angles
            // Pick the position closest to center-x and lowest y (gravity feel)
            var bestPos: CGPoint? = nil
            var bestScore: CGFloat = .infinity

            for existing in placed {
                let touchDist = existing.radius + expandedR
                let angleSteps = 24
                for step in 0..<angleSteps {
                    let angle = (CGFloat(step) / CGFloat(angleSteps)) * 2 * .pi
                    // Deterministic offset per sphere for variety
                    let angleJitter = CGFloat(((index * 7 + step * 13) % 10) - 5) * 0.03
                    let candidate = CGPoint(
                        x: existing.center.x + cos(angle + angleJitter) * touchDist,
                        y: existing.center.y + sin(angle + angleJitter) * touchDist
                    )

                    // Must stay within bounds
                    guard candidate.x - r > 8,
                          candidate.x + r < containerWidth - 8,
                          candidate.y - r > 20 else { continue }

                    // Must not overlap any placed ball
                    let overlaps = placed.contains { p in
                        let dx = candidate.x - p.center.x
                        let dy = candidate.y - p.center.y
                        return sqrt(dx * dx + dy * dy) < (p.radius + expandedR - 2)
                    }
                    guard !overlaps else { continue }

                    // Score: prefer center-ish x, low y, slight randomness
                    let xPull = abs(candidate.x - centerX) * 0.8
                    let yPull = candidate.y * 1.2
                    let jitter = CGFloat((index * 31 + step * 17) % 20)
                    let score = xPull + yPull + jitter

                    if score < bestScore {
                        bestScore = score
                        bestPos = candidate
                    }
                }
            }

            let finalPos = bestPos ?? CGPoint(x: centerX, y: (placed.last?.center.y ?? 100) + r * 2 + gap)
            placed.append((center: finalPos, radius: expandedR))
            positions.append(finalPos)
        }

        let maxY = positions.map(\.y).max() ?? 100
        let maxR = spheres.map { ballDiameter(for: $0.priorityRank) / 2 }.max() ?? 65
        let totalHeight = maxY + maxR + 60

        return PackResult(positions: positions, totalHeight: totalHeight)
    }

    private func deleteSphereFromGrid(_ sphere: SphereModel) {
        for loop in sphere.loops ?? [] {
            modelContext.delete(loop)
        }
        modelContext.delete(sphere)
        try? modelContext.save()
        sphereToDelete = nil
    }

    // MARK: - Reorder Spheres
    private func reorderSpheres(from source: SphereModel, to target: SphereModel) {
        let sourceIndex = spheres.firstIndex(where: { $0.id == source.id }) ?? 0
        let targetIndex = spheres.firstIndex(where: { $0.id == target.id }) ?? 0

        if sourceIndex < targetIndex {
            for i in (sourceIndex + 1)...targetIndex {
                spheres[i].priorityRank = i - 1
            }
            source.priorityRank = targetIndex
        } else {
            for i in targetIndex..<sourceIndex {
                spheres[i].priorityRank = i + 1
            }
            source.priorityRank = targetIndex
        }

        try? modelContext.save()
    }
}

// MARK: - Bouncy Sphere Orb (Floating Ball → Card on Hover)
struct BouncySphereOrb: View {
    let sphere: SphereModel
    let loops: [OpenLoopModel]
    let ballSize: CGFloat
    let onTap: () -> Void
    var onQuickView: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @Binding var hoveredSphereId: UUID?

    @State private var isHovered = false
    @State private var floatY: CGFloat = 0
    @State private var floatX: CGFloat = 0
    @State private var breatheScale: CGFloat = 1.0
    @State private var glowPulse: Double = 0.3
    @State private var hasStartedAnimations = false

    private var activeLoops: [OpenLoopModel] {
        loops.filter { !$0.isCompleted }.sorted { $0.importance < $1.importance }
    }

    // Morphing dimensions
    private var morphWidth: CGFloat { isHovered ? max(ballSize * 1.8, 200) : ballSize }
    private var morphHeight: CGFloat { isHovered ? max(ballSize * 2.2, 220) : ballSize }
    private var morphCornerRadius: CGFloat { isHovered ? 20 : ballSize / 2 }

    private var sphereGradient: LinearGradient {
        LinearGradient(
            colors: [sphere.color, sphere.color.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer glow halo (fades out on hover)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [sphere.color.opacity(glowPulse * 0.4), sphere.color.opacity(0.05), .clear],
                            center: .center,
                            startRadius: ballSize * 0.25,
                            endRadius: ballSize * 0.7
                        )
                    )
                    .frame(width: ballSize * 1.5, height: ballSize * 1.5)
                    .opacity(isHovered ? 0 : 1)
                    .allowsHitTesting(false)

                // Morphing shape: circle → rounded card
                RoundedRectangle(cornerRadius: morphCornerRadius, style: .continuous)
                    .fill(
                        isHovered
                            ? LinearGradient(colors: [SpheresTheme.surface, SpheresTheme.surface], startPoint: .top, endPoint: .bottom)
                            : sphereGradient
                    )
                    .frame(width: morphWidth, height: morphHeight)
                    .overlay(
                        // Glass highlight on ball
                        RoundedRectangle(cornerRadius: morphCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(isHovered ? 0 : 0.22), .clear, .clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: morphCornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: isHovered
                                        ? [sphere.color.opacity(0.5), sphere.color.opacity(0.3)]
                                        : [.white.opacity(0.3), sphere.color.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isHovered ? 1.5 : 1
                            )
                    )
                    .shadow(
                        color: sphere.color.opacity(isHovered ? 0.35 : 0.3),
                        radius: isHovered ? 16 : 8,
                        y: isHovered ? 6 : 4
                    )

                // Ball content (icon + name + count) — visible when NOT hovered
                if !isHovered {
                    VStack(spacing: 4) {
                        Image(systemName: sphere.icon)
                            .font(.system(size: ballSize * 0.22, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 1, y: 1)

                        Text(sphere.name)
                            .font(.system(size: ballSize * 0.11, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text("\(activeLoops.count)")
                            .font(.system(size: ballSize * 0.08, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.black.opacity(0.2)))
                    }
                    .frame(width: ballSize * 0.72)
                    .transition(.opacity)
                }

                // Expanded card content — visible when hovered
                if isHovered {
                    VStack(alignment: .leading, spacing: 8) {
                        // Header
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(sphereGradient)
                                    .frame(width: 32, height: 32)
                                Image(systemName: sphere.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(sphere.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(SpheresTheme.textPrimary)
                                Text("\(activeLoops.count) open loop\(activeLoops.count == 1 ? "" : "s")")
                                    .font(.system(size: 10))
                                    .foregroundColor(SpheresTheme.textTertiary)
                            }
                            Spacer()
                        }

                        Divider().background(SpheresTheme.border)

                        // Loop list
                        if activeLoops.isEmpty {
                            Text("All clear!")
                                .font(.system(size: 11))
                                .foregroundColor(SpheresTheme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(activeLoops.prefix(4)) { loop in
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(sphere.color.opacity(0.6))
                                            .frame(width: 4, height: 4)
                                        Text(loop.content)
                                            .font(.system(size: 11))
                                            .foregroundColor(SpheresTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                if activeLoops.count > 4 {
                                    Text("+\(activeLoops.count - 4) more")
                                        .font(.system(size: 10))
                                        .foregroundColor(SpheresTheme.textTertiary)
                                }
                            }
                        }

                        Spacer(minLength: 0)

                        // Quick view button
                        Button(action: { onQuickView?() }) {
                            Text("Quick View")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(sphere.color)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(sphere.color.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .frame(width: morphWidth, height: morphHeight)
                    .transition(.opacity)
                }
            }
            .frame(width: morphWidth, height: morphHeight)
            .animation(.spring(response: 0.45, dampingFraction: 0.6), value: isHovered)
            .scaleEffect(isHovered ? 1.0 : breatheScale)
            .offset(x: isHovered ? 0 : floatX, y: isHovered ? -8 : floatY)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                isHovered = hovering
                hoveredSphereId = hovering ? sphere.id : nil
            }
        }
        .contextMenu {
            Button(action: { onEdit?() }) {
                Label("Edit Sphere", systemImage: "pencil")
            }
            Button(action: { onQuickView?() }) {
                Label("Quick View", systemImage: "eye")
            }
            Divider()
            Button(role: .destructive, action: { onDelete?() }) {
                Label("Delete Sphere", systemImage: "trash")
            }
        }
        .onAppear { startFloatAnimations() }
    }

    // MARK: - Idle Float Animations (each ball has its own rhythm)
    private func startFloatAnimations() {
        guard !hasStartedAnimations else { return }
        hasStartedAnimations = true

        let seed = Double(sphere.priorityRank)

        // Gentle vertical bob
        withAnimation(
            .easeInOut(duration: 3.2 + seed * 0.3)
            .repeatForever(autoreverses: true)
        ) {
            floatY = 6
        }

        // Slight horizontal drift
        withAnimation(
            .easeInOut(duration: 4.0 + seed * 0.5)
            .repeatForever(autoreverses: true)
        ) {
            floatX = 3
        }

        // Breathe scale
        withAnimation(
            .easeInOut(duration: 2.8 + seed * 0.25)
            .repeatForever(autoreverses: true)
        ) {
            breatheScale = 1.035
        }

        // Glow pulse
        withAnimation(
            .easeInOut(duration: 2.2 + seed * 0.2)
            .repeatForever(autoreverses: true)
        ) {
            glowPulse = 0.65
        }
    }
}

// MARK: - Add Sphere Sheet
struct AddSphereSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor = Color.purple
    @State private var priorityRank = 3

    let colors: [Color] = [.purple, .blue, .green, .orange, .red, .pink, .yellow, .cyan, .mint, .indigo, .teal, .brown]

    private let icons = [
        "star.fill", "heart.fill", "briefcase.fill", "book.fill", "graduationcap.fill",
        "figure.run", "cross.fill", "dollarsign.circle.fill", "house.fill", "person.2.fill",
        "leaf.fill", "paintbrush.fill", "music.note", "globe.americas.fill", "lightbulb.fill",
        "flame.fill", "hands.sparkles.fill", "bolt.fill", "sparkles", "sun.max.fill",
        "moon.fill", "cloud.fill", "pencil", "doc.fill", "folder.fill",
        "envelope.fill", "phone.fill", "desktopcomputer", "camera.fill", "film"
    ]

    var body: some View {
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

            // Preview + Priority + Name
            HStack(spacing: 14) {
                // Sphere icon with priority badge
                ZStack(alignment: .bottomTrailing) {
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

                    // Priority badge
                    Text("\(priorityRank)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(priorityColor(priorityRank)))
                        .offset(x: 4, y: 4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    // Priority selector
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { rank in
                            Button(action: { priorityRank = rank }) {
                                Text("\(rank)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(priorityRank == rank ? .white : priorityColor(rank))
                                    .frame(width: 26, height: 26)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(priorityRank == rank ? priorityColor(rank) : priorityColor(rank).opacity(0.15))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Name field
                    TextField("e.g., Health, Career, Family", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SpheresTheme.background)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpheresTheme.border))
                        )
                }
            }

            // Icon
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 8) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: { selectedIcon = icon }) {
                            Image(systemName: icon)
                                .font(.system(size: 15))
                                .foregroundColor(selectedIcon == icon ? .white : SpheresTheme.textSecondary)
                                .frame(width: 34, height: 34)
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
        .frame(width: 460)
        .background(SpheresTheme.surface)
    }

    private func priorityColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.9, green: 0.2, blue: 0.15)   // Fiery red
        case 2: return Color(red: 0.85, green: 0.35, blue: 0.25)  // Warm red-orange
        case 3: return Color(red: 0.75, green: 0.45, blue: 0.35)  // Muted terracotta
        case 4: return Color(red: 0.55, green: 0.5, blue: 0.48)   // Warm gray
        default: return Color(red: 0.4, green: 0.4, blue: 0.4)    // Cool gray
        }
    }

    private func createSphere() {
        let _ = DataManager.shared.createSphere(
            name: name,
            icon: selectedIcon,
            color: selectedColor,
            description: "",
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
    @State private var selectedIcon: String = ""
    @State private var selectedColor: Color = .purple
    @State private var priorityRank: Int = 3

    let colors: [Color] = [.purple, .blue, .green, .orange, .red, .pink, .yellow, .cyan, .mint, .indigo, .teal, .brown]

    private let icons = [
        "star.fill", "heart.fill", "briefcase.fill", "book.fill", "graduationcap.fill",
        "figure.run", "cross.fill", "dollarsign.circle.fill", "house.fill", "person.2.fill",
        "leaf.fill", "paintbrush.fill", "music.note", "globe.americas.fill", "lightbulb.fill",
        "flame.fill", "hands.sparkles.fill", "bolt.fill", "sparkles", "sun.max.fill",
        "moon.fill", "cloud.fill", "pencil", "doc.fill", "folder.fill",
        "envelope.fill", "phone.fill", "desktopcomputer", "camera.fill", "film"
    ]

    var body: some View {
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

            // Preview + Priority + Name
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
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

                    Text("\(priorityRank)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(priorityColor(priorityRank)))
                        .offset(x: 4, y: 4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { rank in
                            Button(action: { priorityRank = rank }) {
                                Text("\(rank)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(priorityRank == rank ? .white : priorityColor(rank))
                                    .frame(width: 26, height: 26)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(priorityRank == rank ? priorityColor(rank) : priorityColor(rank).opacity(0.15))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TextField("Sphere name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SpheresTheme.background)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpheresTheme.border))
                        )
                }
            }

            // Icon
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SpheresTheme.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 8) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: { selectedIcon = icon }) {
                            Image(systemName: icon)
                                .font(.system(size: 15))
                                .foregroundColor(selectedIcon == icon ? .white : SpheresTheme.textSecondary)
                                .frame(width: 34, height: 34)
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
        .frame(width: 460)
        .background(SpheresTheme.surface)
        .onAppear {
            name = sphere.name
            selectedIcon = sphere.icon
            selectedColor = sphere.color
            priorityRank = sphere.priorityRank
        }
    }

    private func priorityColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.9, green: 0.2, blue: 0.15)
        case 2: return Color(red: 0.85, green: 0.35, blue: 0.25)
        case 3: return Color(red: 0.75, green: 0.45, blue: 0.35)
        case 4: return Color(red: 0.55, green: 0.5, blue: 0.48)
        default: return Color(red: 0.4, green: 0.4, blue: 0.4)
        }
    }

    private func saveSphere() {
        sphere.name = name
        sphere.icon = selectedIcon
        sphere.setColor(selectedColor)
        sphere.priorityRank = priorityRank
        try? modelContext.save()
    }
}

// MARK: - Rounded Sphere Card (Card Grid View)
struct RoundedSphereCard: View {
    let sphere: SphereModel
    let loops: [OpenLoopModel]
    let onTap: () -> Void
    var onQuickView: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var isHovered = false

    private var activeLoops: [OpenLoopModel] {
        loops.filter { !$0.isCompleted }.sorted { $0.importance < $1.importance }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Header: icon + name
                HStack(spacing: 10) {
                    ZStack {
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
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sphere.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(SpheresTheme.textPrimary)
                            .lineLimit(1)

                        Text("\(activeLoops.count) open loop\(activeLoops.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundColor(SpheresTheme.textTertiary)
                    }

                    Spacer()
                }

                Divider()
                    .background(SpheresTheme.border)

                // Loop previews
                if activeLoops.isEmpty {
                    Text("All clear!")
                        .font(.system(size: 12))
                        .foregroundColor(SpheresTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(activeLoops.prefix(4)) { loop in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(sphere.color.opacity(0.6))
                                    .frame(width: 5, height: 5)
                                Text(loop.content)
                                    .font(.system(size: 12))
                                    .foregroundColor(SpheresTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        if activeLoops.count > 4 {
                            Text("+\(activeLoops.count - 4) more")
                                .font(.system(size: 11))
                                .foregroundColor(SpheresTheme.textTertiary)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Priority bar
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { rank in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(rank <= sphere.priorityRank ? sphere.color.opacity(0.6) : SpheresTheme.border)
                            .frame(height: 3)
                    }
                }
            }
            .padding(14)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(SpheresTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isHovered ? sphere.color.opacity(0.5) : SpheresTheme.border, lineWidth: 1)
            )
            .shadow(color: isHovered ? sphere.color.opacity(0.2) : .black.opacity(0.1), radius: isHovered ? 12 : 4, y: isHovered ? 4 : 2)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(action: { onEdit?() }) {
                Label("Edit Sphere", systemImage: "pencil")
            }
            Button(action: { onQuickView?() }) {
                Label("Quick View", systemImage: "eye")
            }
            Divider()
            Button(role: .destructive, action: { onDelete?() }) {
                Label("Delete Sphere", systemImage: "trash")
            }
        }
    }
}

// MARK: - Previews
#Preview("Spheres View") {
    SpheresView()
        .modelContainer(previewContainer)
        .frame(width: 800, height: 600)
}

#Preview("Add Sphere") {
    AddSphereSheet(isPresented: .constant(true))
        .modelContainer(previewContainer)
}

#Preview("Edit Sphere") {
    let sphere = SphereModel(name: "Health", icon: "heart.fill", color: .red, description: "Physical wellness", priorityRank: 1)
    EditSphereSheet(sphere: sphere, isPresented: .constant(true))
        .modelContainer(previewContainer)
}
