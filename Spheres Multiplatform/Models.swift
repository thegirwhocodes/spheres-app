//
//  Models.swift
//  Spheres - Smart Life Manager
//
//  SwiftData models for persistent storage
//

import SwiftUI
import SwiftData

// MARK: - Sphere Model
@Model
final class SphereModel {
    // CloudKit requires all attributes to have default values
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "circle.fill"
    var customImageData: Data?
    var sphereDescription: String = ""
    var priorityRank: Int = 3
    var createdDate: Date = Date()

    // Color components (SwiftData can't store Color directly)
    var colorRed: Double = 0.5
    var colorGreen: Double = 0.5
    var colorBlue: Double = 0.5

    // Relationship to loops (optional for CloudKit)
    @Relationship(deleteRule: .cascade, inverse: \OpenLoopModel.sphere)
    var loops: [OpenLoopModel]? = []

    var color: Color {
        Color(red: colorRed, green: colorGreen, blue: colorBlue)
    }

    init(
        name: String,
        icon: String,
        color: Color,
        description: String = "",
        priorityRank: Int = 3,
        customImageData: Data? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.sphereDescription = description
        self.priorityRank = priorityRank
        self.customImageData = customImageData
        self.createdDate = Date()

        // Extract color components - convert to sRGB first
        let (r, g, b) = SphereModel.extractRGB(from: color)
        self.colorRed = r
        self.colorGreen = g
        self.colorBlue = b
    }

    func setColor(_ color: Color) {
        let (r, g, b) = SphereModel.extractRGB(from: color)
        self.colorRed = r
        self.colorGreen = g
        self.colorBlue = b
    }

    private static func extractRGB(from color: Color) -> (Double, Double, Double) {
        // Convert SwiftUI Color to NSColor, then to sRGB color space
        let nsColor = NSColor(color)

        // Try to convert to sRGB color space first
        if let rgbColor = nsColor.usingColorSpace(.sRGB) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return (Double(red), Double(green), Double(blue))
        }

        // Fallback: try to get components directly
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // If still 0, use some defaults based on common colors
        if red == 0 && green == 0 && blue == 0 {
            // Default to purple if conversion fails
            return (0.5, 0.0, 0.5)
        }

        return (Double(red), Double(green), Double(blue))
    }
}

// MARK: - OpenLoop Model
@Model
final class OpenLoopModel {
    // CloudKit requires all attributes to have default values
    var id: UUID = UUID()
    var content: String = ""
    var importance: Int = 3  // 1-5 (1 = highest priority)
    var progress: Double = 0.0 // 0.0 to 1.0
    var estimatedMinutes: Int?
    var createdDate: Date = Date()
    var isCompleted: Bool = false
    var dueDate: Date?

    // Time tracking
    var timeSpentSeconds: Int = 0
    var timerStartDate: Date?
    var completedDate: Date?

    // Habit/streak tracking
    var isHabit: Bool = false
    var lastCompletedDate: Date?
    var currentStreak: Int = 0

    // Recurring task settings
    var isRecurring: Bool = false
    var recurrenceType: String = "none"  // none, daily, weekly, monthly, custom
    var recurrenceInterval: Int = 1      // every X days/weeks/months
    var recurrenceDays: String = ""      // for weekly: comma-separated day numbers (1=Mon, 7=Sun)
    var nextOccurrence: Date?

    // Manual sort order for drag-to-reorder
    var sortOrder: Int = 0

    // Relationship to sphere (optional for CloudKit)
    var sphere: SphereModel?

    init(
        content: String,
        sphere: SphereModel? = nil,
        importance: Int = 3,
        progress: Double = 0.0,
        estimatedMinutes: Int? = nil,
        dueDate: Date? = nil,
        isHabit: Bool = false,
        isRecurring: Bool = false,
        recurrenceType: String = "none"
    ) {
        self.id = UUID()
        self.content = content
        self.sphere = sphere
        self.importance = importance
        self.progress = progress
        self.estimatedMinutes = estimatedMinutes
        self.createdDate = Date()
        self.isCompleted = false
        self.dueDate = dueDate
        self.timeSpentSeconds = 0
        self.timerStartDate = nil
        self.completedDate = nil
        self.isHabit = isHabit
        self.lastCompletedDate = nil
        self.currentStreak = 0
        self.isRecurring = isRecurring
        self.recurrenceType = recurrenceType
        self.recurrenceInterval = 1
        self.recurrenceDays = ""
        self.nextOccurrence = nil
        self.sortOrder = 0
    }

    // Check if timer is currently running
    var isTimerRunning: Bool {
        timerStartDate != nil
    }

    // Get total time including current session
    var totalTimeSpent: Int {
        if let start = timerStartDate {
            return timeSpentSeconds + Int(Date().timeIntervalSince(start))
        }
        return timeSpentSeconds
    }

    // Recurrence type enum helper
    var recurrenceTypeEnum: RecurrenceType {
        get { RecurrenceType(rawValue: recurrenceType) ?? .none }
        set { recurrenceType = newValue.rawValue }
    }

    // Calculate next occurrence date
    func calculateNextOccurrence(from date: Date = Date()) -> Date? {
        guard isRecurring else { return nil }

        let calendar = Calendar.current

        switch recurrenceTypeEnum {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: recurrenceInterval, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: recurrenceInterval, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: recurrenceInterval, to: date)
        case .custom:
            // For custom, use days from recurrenceDays
            return calendar.date(byAdding: .day, value: recurrenceInterval, to: date)
        }
    }

    // Human-readable recurrence description
    var recurrenceDescription: String {
        guard isRecurring else { return "" }

        switch recurrenceTypeEnum {
        case .none:
            return ""
        case .daily:
            return recurrenceInterval == 1 ? "Daily" : "Every \(recurrenceInterval) days"
        case .weekly:
            return recurrenceInterval == 1 ? "Weekly" : "Every \(recurrenceInterval) weeks"
        case .monthly:
            return recurrenceInterval == 1 ? "Monthly" : "Every \(recurrenceInterval) months"
        case .custom:
            return "Custom"
        }
    }
}

// MARK: - Recurrence Type
enum RecurrenceType: String, CaseIterable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .none: return "calendar"
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar.circle"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - InboxItem Model
@Model
final class InboxItemModel {
    // CloudKit requires all attributes to have default values
    var id: UUID = UUID()
    var content: String = ""
    var capturedDate: Date = Date()
    var suggestedSphereId: UUID?
    var isProcessed: Bool = false

    init(content: String, suggestedSphereId: UUID? = nil) {
        self.id = UUID()
        self.content = content
        self.capturedDate = Date()
        self.suggestedSphereId = suggestedSphereId
        self.isProcessed = false
    }
}

// MARK: - AISuggestion (kept as struct - transient data)
struct AISuggestion: Identifiable {
    var id = UUID()
    var title: String
    var description: String
    var type: SuggestionType

    enum SuggestionType {
        case newSphere
        case resurface
        case schedule
        case insight
    }
}
