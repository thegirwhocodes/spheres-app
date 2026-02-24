//
//  SpheresView.swift
//  Spheres - Smart Life Manager
//
//  Spheres grid view, compact cards, add/edit sphere sheets.
//

import SwiftUI
import SwiftData

// MARK: - Spheres View (Dual Mode: Bubbles + Cards)
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

                            Text("\(spheres.count) spheres")
                                .font(.system(size: 14))
                                .foregroundColor(SpheresTheme.textSecondary)
                        }

                        Spacer()

                        // Page indicator dots
                        HStack(spacing: 8) {
                            Circle()
                                .fill(showingCardView ? SpheresTheme.textTertiary.opacity(0.4) : SpheresTheme.textPrimary)
                                .frame(width: 7, height: 7)
                            Circle()
                                .fill(showingCardView ? SpheresTheme.textPrimary : SpheresTheme.textTertiary.opacity(0.4))
                                .frame(width: 7, height: 7)
                        }
                        .animation(.easeInOut(duration: 0.2), value: showingCardView)

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

                    // Swipeable content area
                    GeometryReader { containerGeo in
                        HStack(spacing: 0) {
                            // Page 1: Bouncy Bubbles
                            bubblesPage
                                .frame(width: containerGeo.size.width)

                            // Page 2: Rounded Card Grid
                            cardGridPage
                                .frame(width: containerGeo.size.width)
                        }
                        .offset(x: showingCardView ? -containerGeo.size.width + swipeDragOffset : swipeDragOffset)
                        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showingCardView)
                        .gesture(
                            DragGesture(minimumDistance: 30)
                                .onChanged { value in
                                    // Only allow horizontal swipes
                                    if abs(value.translation.width) > abs(value.translation.height) {
                                        swipeDragOffset = value.translation.width
                                    }
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = 80
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                        if value.translation.width < -threshold && !showingCardView {
                                            showingCardView = true
                                        } else if value.translation.width > threshold && showingCardView {
                                            showingCardView = false
                                        }
                                        swipeDragOffset = 0
                                    }
                                }
                        )
                    }
                    .clipped()
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

    // MARK: - Page 1: Bouncy Bubbles
    @State private var hoveredBallId: UUID? = nil

    private var bubblesPage: some View {
        ScrollView {
            GeometryReader { geo in
                let packed = packCircles(containerWidth: geo.size.width)

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
                            hoveredBallId: $hoveredBallId
                        )
                        .position(x: pos.x, y: pos.y)
                        .zIndex(hoveredBallId == sphere.id ? 100 : Double(10 - sphere.priorityRank))
                        .opacity(draggingSphere?.id == sphere.id ? 0.4 : 1.0)
                        .draggable(sphere.id.uuidString) {
                            ZStack {
                                Circle()
                                    .fill(sphere.color.opacity(0.85))
                                    .frame(width: 60, height: 60)
                                Image(systemName: sphere.icon)
                                    .font(.system(size: 20))
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
            .frame(minHeight: packCircles(containerWidth: 700).totalHeight)
            .padding(.top, 8)
        }
    }

    // MARK: - Physics Circle Packing
    // Balls tumble into a pile — big ones first, smaller ones nestle into gaps.
    // Uses deterministic seeded randomness so layout is stable per sphere set.
    private struct PackResult {
        let positions: [CGPoint]
        let totalHeight: CGFloat
    }

    private func packCircles(containerWidth: CGFloat) -> PackResult {
        guard !spheres.isEmpty else { return PackResult(positions: [], totalHeight: 300) }

        let radii = spheres.map { ballDiameter(for: $0.priorityRank) / 2 }
        let centerX = containerWidth / 2
        let startY: CGFloat = radii[0] + 20  // first ball near top
        var placed: [(CGPoint, CGFloat)] = []  // (center, radius)
        var positions: [CGPoint] = []

        for (i, r) in radii.enumerated() {
            if i == 0 {
                // First ball: center, slightly randomized
                let pos = CGPoint(x: centerX + seededRandom(seed: i, range: -20...20),
                                  y: startY)
                placed.append((pos, r))
                positions.append(pos)
                continue
            }

            // Try to place this ball touching an existing ball, pulled toward center
            var bestPos = CGPoint(x: centerX, y: startY)
            var bestScore: CGFloat = .infinity

            // Try multiple angles around each placed ball
            for (j, (existingCenter, existingR)) in placed.enumerated() {
                let touchDist = existingR + r + 4  // 4pt gap so they don't z-fight

                for angleStep in 0..<16 {
                    // Spread angles with a seeded offset so each ball picks differently
                    let baseAngle = Double(angleStep) * (.pi * 2 / 16)
                    let jitter = seededRandom(seed: i * 17 + j * 7 + angleStep, range: -0.15...0.15)
                    let angle = baseAngle + jitter

                    let candidateX = existingCenter.x + touchDist * CGFloat(cos(angle))
                    let candidateY = existingCenter.y + touchDist * CGFloat(sin(angle))

                    // Keep within bounds
                    let margin: CGFloat = r + 10
                    guard candidateX > margin && candidateX < containerWidth - margin else { continue }
                    guard candidateY > r else { continue }

                    // Check no overlap with other placed balls
                    var overlaps = false
                    for (otherCenter, otherR) in placed {
                        let dx = candidateX - otherCenter.x
                        let dy = candidateY - otherCenter.y
                        let dist = sqrt(dx * dx + dy * dy)
                        if dist < otherR + r + 2 {
                            overlaps = true
                            break
                        }
                    }
                    if overlaps { continue }

                    // Score: prefer positions close to center-x and low y (gravity pull down + center)
                    let xPull = abs(candidateX - centerX) * 0.8
                    let yPull = candidateY * 1.2  // heavier weight on staying low = piling up
                    let score = xPull + yPull

                    if score < bestScore {
                        bestScore = score
                        bestPos = CGPoint(x: candidateX, y: candidateY)
                    }
                }
            }

            placed.append((bestPos, r))
            positions.append(bestPos)
        }

        let maxY = positions.enumerated().map { (i, p) in p.y + radii[i] }.max() ?? 200
        return PackResult(positions: positions, totalHeight: maxY + 40)
    }

    // Deterministic pseudo-random for stable layout
    private func seededRandom(seed: Int, range: ClosedRange<Double>) -> Double {
        let hash = abs(seed &* 2654435761 &+ 2246822519)
        let normalized = Double(hash % 10000) / 10000.0  // 0.0 ..< 1.0
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }

    // MARK: - Page 2: Rounded Card Grid
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
                    .draggable(sphere.id.uuidString) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(sphere.color.opacity(0.85))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: sphere.icon)
                                    .font(.system(size: 24))
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            reorderSpheres(from: sourceSphere, to: sphere)
                        }
                        draggingSphere = nil
                        return true
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Ball Sizing
    private func ballDiameter(for rank: Int) -> CGFloat {
        switch rank {
        case 1: return 130
        case 2: return 110
        case 3: return 95
        case 4: return 80
        default: return 70
        }
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

// MARK: - Bouncy Sphere Orb (Physical ball with hard edge)
struct BouncySphereOrb: View {
    let sphere: SphereModel
    let loops: [OpenLoopModel]
    let ballSize: CGFloat
    let onTap: () -> Void
    var onQuickView: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @Binding var hoveredBallId: UUID?

    @State private var isHovered = false
    @State private var floatOffset: CGFloat = 0
    @State private var floatScale: CGFloat = 1.0
    @State private var hasStartedFloating = false

    private var activeLoops: [OpenLoopModel] {
        loops.filter { !$0.isCompleted }.sorted { $0.importance < $1.importance }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Contact shadow (ellipse underneath — like ball sitting on surface)
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [.black.opacity(0.25), .black.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: ballSize * 0.45
                        )
                    )
                    .frame(width: ballSize * 0.8, height: ballSize * 0.25)
                    .offset(y: ballSize * 0.48)
                    .blur(radius: 3)

                // Main ball body — radial gradient for 3D depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                sphere.color.opacity(0.95),        // bright center
                                sphere.color,                       // true color
                                sphere.color.opacity(0.65),         // darker rim
                                sphere.color.opacity(0.4)           // very dark edge
                            ],
                            center: UnitPoint(x: 0.38, y: 0.32),  // light source top-left
                            startRadius: ballSize * 0.05,
                            endRadius: ballSize * 0.55
                        )
                    )
                    .frame(width: ballSize, height: ballSize)

                // Hard rim edge — crisp stroke that makes it feel solid
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.5),                // lit edge top-left
                                sphere.color.opacity(0.3),          // mid
                                .black.opacity(0.35)                // shadow edge bottom-right
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: ballSize, height: ballSize)

                // Specular highlight — small bright dot like a real shiny ball
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.85), .white.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: ballSize * 0.14
                        )
                    )
                    .frame(width: ballSize * 0.28, height: ballSize * 0.22)
                    .offset(x: -ballSize * 0.18, y: -ballSize * 0.2)

                // Secondary soft highlight — broader diffuse
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: ballSize * 0.6, height: ballSize * 0.35)
                    .offset(y: -ballSize * 0.15)

                // Content: icon + name + count
                VStack(spacing: ballSize * 0.03) {
                    Image(systemName: sphere.icon)
                        .font(.system(size: ballSize * 0.24, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)

                    Text(sphere.name)
                        .font(.system(size: ballSize * 0.12, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .lineLimit(1)

                    if ballSize >= 90 {
                        Text("\(activeLoops.count) open")
                            .font(.system(size: ballSize * 0.08, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.black.opacity(0.25)))
                    }
                }
            }
            .frame(width: ballSize, height: ballSize)
            .scaleEffect(isHovered ? 1.12 : floatScale)
            .offset(y: isHovered ? -6 : floatOffset)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isHovered = hovering
                hoveredBallId = hovering ? sphere.id : nil
            }
        }
        .contextMenu {
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Edit Sphere", systemImage: "pencil")
                }
            }
            if let onQuickView = onQuickView {
                Button(action: onQuickView) {
                    Label("Quick View", systemImage: "eye")
                }
            }
            Divider()
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Sphere", systemImage: "trash")
                }
            }
        }
        .onAppear { startIdleAnimations() }
    }

    // MARK: - Idle Animations (subtle — real balls don't float much)
    private func startIdleAnimations() {
        guard !hasStartedFloating else { return }
        hasStartedFloating = true

        let rankOffset = Double(sphere.priorityRank)

        // Very subtle wobble — like balls settling
        withAnimation(
            .easeInOut(duration: 3.5 + rankOffset * 0.4)
            .repeatForever(autoreverses: true)
        ) {
            floatOffset = 3
        }

        withAnimation(
            .easeInOut(duration: 4.0 + rankOffset * 0.3)
            .repeatForever(autoreverses: true)
        ) {
            floatScale = 1.015
        }
    }
}

// MARK: - Rounded Sphere Card (Grid View)
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
            VStack(alignment: .leading, spacing: 12) {
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

                        Text("\(activeLoops.count) open")
                            .font(.system(size: 11))
                            .foregroundColor(SpheresTheme.textTertiary)
                    }

                    Spacer()
                }

                // Loop previews
                if !activeLoops.isEmpty {
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
                                .padding(.leading, 11)
                        }
                    }
                } else {
                    Text("No open loops")
                        .font(.system(size: 12))
                        .foregroundColor(SpheresTheme.textMuted)
                        .italic()
                }

                Spacer(minLength: 0)

                // Priority indicator
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level <= (6 - sphere.priorityRank) ? sphere.color : SpheresTheme.border.opacity(0.5))
                            .frame(width: 14, height: 3)
                    }
                    Spacer()
                }
            }
            .padding(16)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(isHovered ? SpheresTheme.surfaceHover : SpheresTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                isHovered ? sphere.color.opacity(0.4) : SpheresTheme.border,
                                lineWidth: isHovered ? 1.5 : 1
                            )
                    )
                    .shadow(
                        color: isHovered ? sphere.color.opacity(0.2) : .black.opacity(0.08),
                        radius: isHovered ? 12 : 6,
                        x: 0,
                        y: isHovered ? 4 : 2
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Edit Sphere", systemImage: "pencil")
                }
            }
            if let onQuickView = onQuickView {
                Button(action: onQuickView) {
                    Label("Quick View", systemImage: "eye")
                }
            }
            Divider()
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Sphere", systemImage: "trash")
                }
            }
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
                        .onSubmit {
                            if !name.isEmpty {
                                createSphere()
                                isPresented = false
                            }
                        }
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
                        .onSubmit {
                            if !name.isEmpty {
                                saveSphere()
                                isPresented = false
                            }
                        }
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

// MARK: - Previews

#Preview("Spheres View") {
    SpheresView()
        .modelContainer(previewContainer)
        .frame(width: 700, height: 500)
}

#Preview("Add Sphere Sheet") {
    AddSphereSheet(isPresented: .constant(true))
        .modelContainer(previewContainer)
}

#Preview("Edit Sphere Sheet") {
    EditSphereSheet(
        sphere: SphereModel(name: "Health", icon: "heart.fill", color: .red, priorityRank: 1),
        isPresented: .constant(true)
    )
    .modelContainer(previewContainer)
}
