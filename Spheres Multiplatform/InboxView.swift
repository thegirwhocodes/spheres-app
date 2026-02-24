//
//  InboxView.swift
//  Spheres - Smart Life Manager
//
//  Inbox for processing captured items.
//

import SwiftUI
import SwiftData

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

            Text(item.content)
                .font(.system(size: 14))
                .foregroundColor(SpheresTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(SpheresTheme.background)
                )

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

#Preview("Inbox View") {
    InboxView()
        .modelContainer(previewContainer)
        .frame(width: 700, height: 500)
}
