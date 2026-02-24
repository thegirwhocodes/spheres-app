//
//  SpheresView.swift
//  Spheres - Smart Life Manager
//
//  Spheres grid view, compact cards, add/edit sphere sheets.
//

import SwiftUI
import SwiftData

// MARK: - Spheres View (Compact Grid)
struct SpheresView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\SphereModel.priorityRank), SortDescriptor(\SphereModel.createdDate)]) private var spheres: [SphereModel]

    @State private var showingAddSphere = false
    @State private var quickViewSphere: SphereModel? = nil
    @State private var selectedSphereForFullView: SphereModel? = nil
    @State private var editingSphereFromGrid: SphereModel? = nil
    @State private var hasSeededData = false
    @State private var draggingSphere: SphereModel? = nil

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
                                        },
                                        onEdit: {
                                            editingSphereFromGrid = sphere
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

                            Spacer()
                                .frame(height: 20)
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
        .sheet(item: $editingSphereFromGrid) { sphere in
            EditSphereSheet(sphere: sphere, isPresented: Binding(
                get: { editingSphereFromGrid != nil },
                set: { if !$0 { editingSphereFromGrid = nil } }
            ))
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
    var onEdit: (() -> Void)? = nil
    @State private var isHovered = false
    @State private var headerHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Header — tappable for edit
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
                        HStack(spacing: 5) {
                            Text(sphere.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(SpheresTheme.textPrimary)

                            Image(systemName: "pencil")
                                .font(.system(size: 9))
                                .foregroundColor(SpheresTheme.textTertiary.opacity(headerHovered ? 0.8 : 0))
                        }

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
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(headerHovered ? sphere.color.opacity(0.06) : Color.clear)
                )
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) { headerHovered = hovering }
                }
                .onTapGesture {
                    onEdit?()
                }

                // Scrollable Loop Preview (only active loops)
                if !loops.filter({ !$0.isCompleted }).isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(loops.filter { !$0.isCompleted }.sorted { $0.importance < $1.importance }) { loop in
                                HStack(alignment: .top, spacing: 8) {
                                    // Bullet in sphere color
                                    Circle()
                                        .fill(sphere.color.opacity(0.5))
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 6)

                                    Text(loop.content)
                                        .font(.system(size: 13))
                                        .foregroundColor(SpheresTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)

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
