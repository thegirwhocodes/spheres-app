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

                    // Cluster Content
                    ScrollView {
                        GeometryReader { geo in
                            let layout = clusterLayout(count: spheres.count, containerWidth: geo.size.width)

                            ZStack(alignment: .topLeading) {
                                ForEach(Array(spheres.enumerated()), id: \.element.id) { index, sphere in
                                    let pos = index < layout.positions.count ? layout.positions[index] : .zero
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
                                        onQuickView: {
                                            quickViewSphere = sphere
                                        },
                                        onEdit: {
                                            editingSphereFromGrid = sphere
                                        },
                                        onDelete: {
                                            sphereToDelete = sphere
                                            showingDeleteConfirmation = true
                                        },
                                        hoveredSphereId: $hoveredSphereId
                                    )
                                    .frame(width: size, height: size)
                                    .position(x: pos.x, y: pos.y)
                                    .zIndex(hoveredSphereId == sphere.id ? 100 : Double(10 - sphere.priorityRank))
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
                            .frame(width: geo.size.width, height: layout.totalHeight)
                        }
                        .frame(minHeight: clusterLayout(count: spheres.count, containerWidth: 800).totalHeight)
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

    // MARK: - Ball Sizing
    private func ballDiameter(for rank: Int) -> CGFloat {
        switch rank {
        case 1: return 240
        case 2: return 210
        case 3: return 185
        case 4: return 165
        default: return 145
        }
    }

    // MARK: - Honeycomb Cluster Layout
    private struct ClusterLayout {
        let positions: [CGPoint]
        let totalHeight: CGFloat
    }

    private func clusterLayout(count: Int, containerWidth: CGFloat) -> ClusterLayout {
        guard count > 0 else { return ClusterLayout(positions: [], totalHeight: 300) }

        // Honeycomb: 3 cols on even rows, 2 cols on odd rows (shifted)
        let hSpacing: CGFloat = 195     // horizontal center-to-center
        let vSpacing: CGFloat = 170     // vertical center-to-center (tight = overlap)
        let stagger: CGFloat = hSpacing / 2

        var positions: [CGPoint] = []
        var idx = 0
        var row = 0

        while idx < count {
            let isWideRow = row % 2 == 0
            let maxInRow = isWideRow ? 3 : 2
            let itemsInRow = min(maxInRow, count - idx)

            // Center the row
            let rowWidth = CGFloat(itemsInRow - 1) * hSpacing
            let rowStartX: CGFloat
            if isWideRow {
                rowStartX = (containerWidth - rowWidth) / 2
            } else {
                let narrowRowWidth = CGFloat(itemsInRow - 1) * hSpacing
                rowStartX = (containerWidth - narrowRowWidth) / 2
            }

            let y = CGFloat(row) * vSpacing + 140  // top padding for largest ball

            for j in 0..<itemsInRow {
                let x = rowStartX + CGFloat(j) * hSpacing
                // Small organic jitter based on index
                let jitterX = CGFloat(((idx + j) * 7 + 3) % 5 - 2) * 4
                let jitterY = CGFloat(((idx + j) * 11 + 1) % 5 - 2) * 3
                positions.append(CGPoint(x: x + jitterX, y: y + jitterY))
            }

            idx += itemsInRow
            row += 1
        }

        let maxY = positions.map(\.y).max() ?? 140
        let totalHeight = maxY + 140  // bottom padding

        return ClusterLayout(positions: positions, totalHeight: totalHeight)
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

// MARK: - Bouncy Sphere Orb (Interactive Ball with content inside)
struct BouncySphereOrb: View {
    let sphere: SphereModel
    let loops: [OpenLoopModel]
    let ballSize: CGFloat
    let onTap: () -> Void
    let onQuickView: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @Binding var hoveredSphereId: UUID?

    @State private var isHovered = false
    @State private var floatOffset: CGFloat = 0
    @State private var floatScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.4
    @State private var hasStartedFloating = false

    private var activeLoops: [OpenLoopModel] {
        loops.filter { !$0.isCompleted }.sorted { $0.importance < $1.importance }
    }

    // How many loops fit inside the ball (depends on size)
    private var visibleLoopCount: Int {
        if ballSize >= 220 { return 4 }
        if ballSize >= 190 { return 3 }
        if ballSize >= 170 { return 2 }
        return 1
    }

    // Content inset — how much to inset text from ball edges to stay inside the circle
    private var contentInset: CGFloat {
        ballSize * 0.18
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer glow halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [sphere.color.opacity(glowOpacity * 0.35), sphere.color.opacity(0.05), .clear],
                            center: .center,
                            startRadius: ballSize * 0.3,
                            endRadius: ballSize * 0.75
                        )
                    )
                    .frame(width: ballSize * 1.4, height: ballSize * 1.4)
                    .allowsHitTesting(false)

                // Main ball
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                sphere.color,
                                sphere.color.opacity(0.7),
                                sphere.color.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: ballSize, height: ballSize)
                    .overlay(
                        // Inner highlight (glass-like shine)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .clear, .clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), sphere.color.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: sphere.color.opacity(isHovered ? 0.6 : 0.35),
                        radius: isHovered ? 20 : 10,
                        x: 0,
                        y: isHovered ? 8 : 5
                    )

                // Content inside ball — clipped to circle
                VStack(spacing: ballSize * 0.03) {
                    // Icon
                    Image(systemName: sphere.icon)
                        .font(.system(size: ballSize * 0.16, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)

                    // Name
                    Text(sphere.name)
                        .font(.system(size: ballSize * 0.085, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Loop count pill
                    Text("\(activeLoops.count) open")
                        .font(.system(size: ballSize * 0.055, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.2))
                        )

                    // Loop previews inside the ball
                    if !activeLoops.isEmpty {
                        VStack(alignment: .leading, spacing: ballSize * 0.02) {
                            ForEach(activeLoops.prefix(visibleLoopCount)) { loop in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.white.opacity(0.5))
                                        .frame(width: 3, height: 3)
                                    Text(loop.content)
                                        .font(.system(size: ballSize * 0.052))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                            if activeLoops.count > visibleLoopCount {
                                Text("+\(activeLoops.count - visibleLoopCount) more")
                                    .font(.system(size: ballSize * 0.045))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.top, ballSize * 0.01)
                    }
                }
                .frame(width: ballSize - contentInset * 2)
                .clipShape(Circle())
            }
            .scaleEffect(isHovered ? 1.08 : floatScale)
            .offset(y: isHovered ? -4 : floatOffset)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                isHovered = hovering
                hoveredSphereId = hovering ? sphere.id : nil
            }
        }
        .contextMenu {
            Button(action: { onEdit?() }) {
                Label("Edit Sphere", systemImage: "pencil")
            }
            Button(action: { onQuickView() }) {
                Label("Quick View", systemImage: "eye")
            }
            Divider()
            Button(role: .destructive, action: { onDelete?() }) {
                Label("Delete Sphere", systemImage: "trash")
            }
        }
        .onAppear { startIdleAnimations() }
    }

    // MARK: - Idle Float Animations
    private func startIdleAnimations() {
        guard !hasStartedFloating else { return }
        hasStartedFloating = true

        let rankOffset = Double(sphere.priorityRank)

        withAnimation(
            .easeInOut(duration: 3.0 + rankOffset * 0.4)
            .repeatForever(autoreverses: true)
        ) {
            floatOffset = 7
        }

        withAnimation(
            .easeInOut(duration: 2.6 + rankOffset * 0.25)
            .repeatForever(autoreverses: true)
        ) {
            floatScale = 1.025
        }

        withAnimation(
            .easeInOut(duration: 2.0 + rankOffset * 0.2)
            .repeatForever(autoreverses: true)
        ) {
            glowOpacity = 0.7
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
