import SwiftUI
import SwiftData

// MARK: - Preview ModelContainer

@MainActor
let previewContainer: ModelContainer = {
    let schema = Schema([SphereModel.self, OpenLoopModel.self, InboxItemModel.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    // Seed sample spheres
    let health = SphereModel(name: "Health", icon: "heart.fill", color: .red, description: "Physical & mental wellness", priorityRank: 1)
    let career = SphereModel(name: "Career", icon: "briefcase.fill", color: .blue, description: "Work & professional growth", priorityRank: 2)
    let family = SphereModel(name: "Family", icon: "person.2.fill", color: .orange, description: "Relationships & loved ones", priorityRank: 3)
    let faith = SphereModel(name: "Faith", icon: "hands.sparkles.fill", color: .purple, description: "Spiritual growth", priorityRank: 4)

    container.mainContext.insert(health)
    container.mainContext.insert(career)
    container.mainContext.insert(family)
    container.mainContext.insert(faith)

    // Seed sample loops
    let loop1 = OpenLoopModel(content: "Morning run - 30 minutes", sphere: health, importance: 1, progress: 0.6, estimatedMinutes: 30, isHabit: true)
    loop1.currentStreak = 5
    let loop2 = OpenLoopModel(content: "Call the dentist", sphere: health, importance: 2, estimatedMinutes: 10)
    let loop3 = OpenLoopModel(content: "Review project proposal", sphere: career, importance: 1, progress: 0.3, estimatedMinutes: 45)
    let loop4 = OpenLoopModel(content: "Update resume", sphere: career, importance: 3, estimatedMinutes: 60)
    let loop5 = OpenLoopModel(content: "Plan family dinner", sphere: family, importance: 2, estimatedMinutes: 20)
    let loop6 = OpenLoopModel(content: "Read devotional", sphere: faith, importance: 2, progress: 1.0, isHabit: true)
    loop6.isCompleted = true
    loop6.currentStreak = 12

    for loop in [loop1, loop2, loop3, loop4, loop5, loop6] {
        container.mainContext.insert(loop)
    }

    return container
}()
