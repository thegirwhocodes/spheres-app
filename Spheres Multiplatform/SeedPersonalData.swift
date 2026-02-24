//
//  SeedPersonalData.swift
//  Spheres - Smart Life Manager
//
//  Seeds personalized spheres and open loops for Naomi Ivie
//  based on Spring 2026 academic schedule, career goals, and life commitments.
//

import SwiftUI
import SwiftData

@MainActor
struct PersonalDataSeeder {

    /// Call once to populate the app with personalized spheres and loops.
    /// Checks AppStorage flag to prevent duplicate seeding.
    static func seedIfNeeded(modelContext: ModelContext) {
        let alreadySeeded = UserDefaults.standard.bool(forKey: "hasSeededPersonalData")
        guard !alreadySeeded else { return }

        seedAll(modelContext: modelContext)
        UserDefaults.standard.set(true, forKey: "hasSeededPersonalData")
    }

    // MARK: - Sphere Matching

    /// Keywords that map to each intended sphere category.
    /// If an existing sphere's name contains any of these keywords, we reuse it.
    private static let sphereKeywords: [String: [String]] = [
        "Academics": ["academics", "school", "class", "course", "study", "education", "learning"],
        "Career": ["career", "job", "intern", "work", "professional", "employment"],
        "Faith": ["faith", "bible", "church", "prayer", "spiritual", "christian", "devotion", "gospel", "worship", "religion"],
        "Community": ["community", "fellowship", "volunteer", "service", "club", "organization", "social impact"],
        "Music": ["music", "sing", "guitar", "choir", "band", "acapella", "ebony"],
        "Spheres App": ["spheres app", "app dev", "development", "coding project"],
        "Health": ["health", "fitness", "exercise", "gym", "wellness", "sport", "basketball"],
        "Finances": ["finance", "money", "invest", "budget", "saving", "banking"]
    ]

    /// Find an existing sphere that matches the intended category, or create a new one.
    private static func findOrCreateSphere(
        category: String,
        name: String,
        icon: String,
        color: Color,
        description: String,
        priorityRank: Int,
        existingSpheres: [SphereModel],
        modelContext: ModelContext
    ) -> SphereModel {
        let keywords = sphereKeywords[category] ?? [category.lowercased()]

        // Check if any existing sphere matches by keyword
        for sphere in existingSpheres {
            let sphereName = sphere.name.lowercased()
            for keyword in keywords {
                if sphereName.contains(keyword) {
                    return sphere // Reuse existing sphere, keep its original name
                }
            }
        }

        // No match — create new sphere
        return DataManager.shared.createSphere(
            name: name, icon: icon, color: color, description: description,
            priorityRank: priorityRank, customImageData: nil, modelContext: modelContext
        )
    }

    /// Check if a loop with similar content already exists in the sphere.
    private static func loopExists(_ content: String, in sphere: SphereModel) -> Bool {
        guard let loops = sphere.loops else { return false }
        let lowered = content.lowercased()
        return loops.contains { $0.content.lowercased().contains(lowered) || lowered.contains($0.content.lowercased()) }
    }

    /// Create a loop only if one with similar content doesn't already exist.
    @discardableResult
    private static func addLoop(
        content: String,
        sphere: SphereModel,
        importance: Int,
        estimatedMinutes: Int?,
        dueDate: Date? = nil,
        isHabit: Bool = false,
        isRecurring: Bool = false,
        recurrenceType: String = "none",
        recurrenceInterval: Int = 1,
        recurrenceDays: String = "",
        modelContext: ModelContext
    ) -> OpenLoopModel? {
        guard !loopExists(content, in: sphere) else { return nil }

        let dm = DataManager.shared
        let loop = dm.createLoop(
            content: content, sphere: sphere, importance: importance,
            progress: 0.0, estimatedMinutes: estimatedMinutes, modelContext: modelContext
        )
        if let due = dueDate {
            dm.updateLoop(loop, dueDate: due, modelContext: modelContext)
        }
        if isHabit { loop.isHabit = true }
        if isRecurring {
            loop.isRecurring = true
            loop.recurrenceType = recurrenceType
            loop.recurrenceInterval = recurrenceInterval
            if !recurrenceDays.isEmpty { loop.recurrenceDays = recurrenceDays }
        }
        return loop
    }

    // MARK: - Main Seed Function

    static func seedAll(modelContext: ModelContext) {
        let cal = Calendar.current

        // Helper to make dates
        func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 23, minute: Int = 59) -> Date {
            var c = DateComponents()
            c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
            return cal.date(from: c) ?? Date()
        }

        // Fetch all existing spheres for matching
        let descriptor = FetchDescriptor<SphereModel>()
        let existingSpheres = (try? modelContext.fetch(descriptor)) ?? []

        // ============================================================
        // MARK: 1. ACADEMICS (Priority 1 — Blue)
        // ============================================================
        let academics = findOrCreateSphere(
            category: "Academics", name: "Academics", icon: "book.fill",
            color: Color(red: 0.3, green: 0.5, blue: 0.9),
            description: "Spring 2026 coursework — 4 courses at Wesleyan",
            priorityRank: 1, existingSpheres: existingSpheres, modelContext: modelContext
        )

        // --- ECON 241: Money, Banking & Financial Markets ---
        addLoop(content: "Study for ECON 241 Exam 1 (Prof. Imai)", sphere: academics, importance: 1, estimatedMinutes: 480, modelContext: modelContext)
        addLoop(content: "ECON 241 Exam 1", sphere: academics, importance: 1, estimatedMinutes: 90, dueDate: date(2026, 3, 2), modelContext: modelContext)
        addLoop(content: "ECON 241 Problem Set #5", sphere: academics, importance: 2, estimatedMinutes: 120, dueDate: date(2026, 3, 24), modelContext: modelContext)
        addLoop(content: "ECON 241 Problem Set #6", sphere: academics, importance: 2, estimatedMinutes: 120, dueDate: date(2026, 3, 31), modelContext: modelContext)
        addLoop(content: "ECON 241 Problem Set #7", sphere: academics, importance: 2, estimatedMinutes: 120, dueDate: date(2026, 4, 7), modelContext: modelContext)
        addLoop(content: "ECON 241 Problem Set #8", sphere: academics, importance: 2, estimatedMinutes: 120, dueDate: date(2026, 4, 14), modelContext: modelContext)
        addLoop(content: "ECON 241 Quiz #2", sphere: academics, importance: 1, estimatedMinutes: 60, dueDate: date(2026, 4, 15), modelContext: modelContext)
        addLoop(content: "ECON 241 Problem Set #9", sphere: academics, importance: 2, estimatedMinutes: 120, dueDate: date(2026, 4, 21), modelContext: modelContext)
        addLoop(content: "ECON 241 Problem Set #10", sphere: academics, importance: 2, estimatedMinutes: 120, dueDate: date(2026, 4, 28), modelContext: modelContext)
        addLoop(content: "ECON 241 Final Exam (Exam 2)", sphere: academics, importance: 1, estimatedMinutes: 120, dueDate: date(2026, 5, 6), modelContext: modelContext)

        // --- ECON 333: Financial Intermediation & Crises ---
        addLoop(content: "Study for ECON 333 Exam 1 (Prof. Izumi, closed book)", sphere: academics, importance: 1, estimatedMinutes: 480, dueDate: date(2026, 3, 5), modelContext: modelContext)
        addLoop(content: "ECON 333: Confirm presentation group & topic (check with Prof. Izumi)", sphere: academics, importance: 1, estimatedMinutes: 30, modelContext: modelContext)
        addLoop(content: "ECON 333: Email research presentation group leader", sphere: academics, importance: 2, estimatedMinutes: 30, dueDate: date(2026, 3, 31), modelContext: modelContext)
        addLoop(content: "ECON 333 Exam 2 (closed book)", sphere: academics, importance: 1, estimatedMinutes: 120, dueDate: date(2026, 4, 23), modelContext: modelContext)
        addLoop(content: "ECON 333 Research Paper Presentation", sphere: academics, importance: 1, estimatedMinutes: 300, dueDate: date(2026, 4, 28), modelContext: modelContext)
        addLoop(content: "ECON 333 Research Paper (7-8 pages, double-spaced)", sphere: academics, importance: 1, estimatedMinutes: 600, dueDate: date(2026, 5, 12), modelContext: modelContext)

        // --- ECON 349: Economic Growth ---
        addLoop(content: "ECON 349 Problem Set #2 (Prof. Kuenzel)", sphere: academics, importance: 1, estimatedMinutes: 120, dueDate: date(2026, 3, 2), modelContext: modelContext)
        addLoop(content: "ECON 349 Problem Set #3", sphere: academics, importance: 2, estimatedMinutes: 120, dueDate: date(2026, 3, 25), modelContext: modelContext)
        addLoop(content: "ECON 349 Exam (in-class, FRANK 002)", sphere: academics, importance: 1, estimatedMinutes: 120, dueDate: date(2026, 3, 30), modelContext: modelContext)
        addLoop(content: "ECON 349 Group Presentation — prepare assigned paper", sphere: academics, importance: 2, estimatedMinutes: 300, modelContext: modelContext)
        addLoop(content: "ECON 349 Final Paper + Presentation", sphere: academics, importance: 1, estimatedMinutes: 600, dueDate: date(2026, 5, 4), modelContext: modelContext)

        // --- QAC 386: Text Mining ---
        addLoop(content: "QAC 386 Homework 3", sphere: academics, importance: 2, estimatedMinutes: 180, dueDate: date(2026, 4, 7, hour: 12, minute: 0), modelContext: modelContext)
        addLoop(content: "QAC 386 Homework 4", sphere: academics, importance: 2, estimatedMinutes: 180, dueDate: date(2026, 4, 21, hour: 12, minute: 0), modelContext: modelContext)
        addLoop(content: "QAC 386 Homework 5", sphere: academics, importance: 2, estimatedMinutes: 180, dueDate: date(2026, 4, 28, hour: 12, minute: 0), modelContext: modelContext)
        addLoop(content: "QAC 386 Mini Project (ProQuest & TDM Studio)", sphere: academics, importance: 2, estimatedMinutes: 360, dueDate: date(2026, 5, 4), modelContext: modelContext)
        addLoop(content: "QAC 386 Final Project", sphere: academics, importance: 1, estimatedMinutes: 600, dueDate: date(2026, 5, 15, hour: 17, minute: 0), modelContext: modelContext)

        // ============================================================
        // MARK: 2. CAREER (Priority 1 — Green)
        // ============================================================
        let career = findOrCreateSphere(
            category: "Career", name: "Career", icon: "briefcase.fill",
            color: Color(red: 0.2, green: 0.7, blue: 0.4),
            description: "Summer 2026 internship search — BA/Consulting/Finance",
            priorityRank: 1, existingSpheres: existingSpheres, modelContext: modelContext
        )

        addLoop(content: "Apply to Capital One Business Analyst internship", sphere: career, importance: 1, estimatedMinutes: 90, modelContext: modelContext)
        addLoop(content: "Apply to Uber data/analytics internship", sphere: career, importance: 1, estimatedMinutes: 90, modelContext: modelContext)
        addLoop(content: "Apply to Stripe BA internship", sphere: career, importance: 2, estimatedMinutes: 90, modelContext: modelContext)
        addLoop(content: "Apply to Robinhood operations/analytics role", sphere: career, importance: 2, estimatedMinutes: 90, modelContext: modelContext)
        addLoop(content: "Reach out to Wesleyan alumni in consulting (McKinsey, Bain, BCG)", sphere: career, importance: 2, estimatedMinutes: 60, modelContext: modelContext)
        addLoop(content: "Reach out to ALA and Dartmouth Tuck Bridge network contacts", sphere: career, importance: 2, estimatedMinutes: 60, modelContext: modelContext)
        addLoop(content: "Practice case interviews — work through McKinsey & Bain guides", sphere: career, importance: 2, estimatedMinutes: 240, modelContext: modelContext)
        addLoop(content: "Tailor resume for each target company (BA vs. Finance vs. Consulting)", sphere: career, importance: 2, estimatedMinutes: 120, modelContext: modelContext)
        addLoop(content: "Follow up on submitted applications", sphere: career, importance: 2, estimatedMinutes: 30, modelContext: modelContext)
        addLoop(content: "Research OPT/CPT sponsorship requirements for target companies", sphere: career, importance: 3, estimatedMinutes: 60, modelContext: modelContext)
        addLoop(content: "Apply to Goldman Sachs / JP Morgan summer analyst roles", sphere: career, importance: 2, estimatedMinutes: 90, modelContext: modelContext)
        addLoop(content: "Update LinkedIn profile with Beza Fintech internship details", sphere: career, importance: 3, estimatedMinutes: 30, modelContext: modelContext)

        // ============================================================
        // MARK: 3. FAITH (Priority 1 — Gold)
        // ============================================================
        let faith = findOrCreateSphere(
            category: "Faith", name: "Faith", icon: "cross.fill",
            color: Color(red: 0.85, green: 0.7, blue: 0.3),
            description: "Spiritual growth, church, prayer, evangelism",
            priorityRank: 1, existingSpheres: existingSpheres, modelContext: modelContext
        )

        addLoop(content: "Daily prayer & devotional time", sphere: faith, importance: 1, estimatedMinutes: 20, isHabit: true, isRecurring: true, recurrenceType: "daily", modelContext: modelContext)
        addLoop(content: "Attend The Oasis Wesleyan service", sphere: faith, importance: 1, estimatedMinutes: 90, isRecurring: true, recurrenceType: "weekly", recurrenceDays: "7", modelContext: modelContext)
        addLoop(content: "Prayer calendar check-in", sphere: faith, importance: 2, estimatedMinutes: 15, isRecurring: true, recurrenceType: "weekly", modelContext: modelContext)
        addLoop(content: "Diary of the Student Evangelist — write next entry", sphere: faith, importance: 2, estimatedMinutes: 45, modelContext: modelContext)
        addLoop(content: "Scripture memorization — pick a verse for the week", sphere: faith, importance: 3, estimatedMinutes: 15, modelContext: modelContext)

        // ============================================================
        // MARK: 4. COMMUNITY (Priority 2 — Orange)
        // ============================================================
        let community = findOrCreateSphere(
            category: "Community", name: "Community", icon: "person.3.fill",
            color: Color(red: 0.9, green: 0.5, blue: 0.2),
            description: "PCE Fellowship, Nigerian Student Association, Education for Equality",
            priorityRank: 2, existingSpheres: existingSpheres, modelContext: modelContext
        )

        addLoop(content: "PCE Social Impact Fellowship — cohort session (4:30-6 PM)", sphere: community, importance: 1, estimatedMinutes: 90, isRecurring: true, recurrenceType: "weekly", modelContext: modelContext)
        addLoop(content: "PCE mentorship session with Shiv Soin (Entrepreneur-in-Residence)", sphere: community, importance: 2, estimatedMinutes: 60, isRecurring: true, recurrenceType: "weekly", modelContext: modelContext)
        addLoop(content: "PCE Capstone Draft", sphere: community, importance: 1, estimatedMinutes: 480, dueDate: date(2026, 4, 3), modelContext: modelContext)
        addLoop(content: "PCE Final Capstone Project", sphere: community, importance: 1, estimatedMinutes: 600, dueDate: date(2026, 5, 14), modelContext: modelContext)
        addLoop(content: "Wesleyan Nigerian Student Association meeting", sphere: community, importance: 2, estimatedMinutes: 60, modelContext: modelContext)
        addLoop(content: "Education for Equality — next event planning", sphere: community, importance: 3, estimatedMinutes: 60, modelContext: modelContext)
        addLoop(content: "Harvard-ALA Africa Innovation Symposium — follow up on connections", sphere: community, importance: 3, estimatedMinutes: 30, modelContext: modelContext)

        // ============================================================
        // MARK: 5. MUSIC (Priority 3 — Pink)
        // ============================================================
        let music = findOrCreateSphere(
            category: "Music", name: "Music", icon: "music.note",
            color: Color(red: 0.85, green: 0.35, blue: 0.6),
            description: "Ebony Singers, guitar, acapella",
            priorityRank: 3, existingSpheres: existingSpheres, modelContext: modelContext
        )

        addLoop(content: "Ebony Singers rehearsal (Mon 7:30-9 PM)", sphere: music, importance: 2, estimatedMinutes: 90, isRecurring: true, recurrenceType: "weekly", recurrenceDays: "1", modelContext: modelContext)
        addLoop(content: "Practice guitar — Saturday Night Live prep", sphere: music, importance: 3, estimatedMinutes: 30, modelContext: modelContext)
        addLoop(content: "Learn Bawo vocal parts (alto, soprano, tenor-bass)", sphere: music, importance: 3, estimatedMinutes: 45, modelContext: modelContext)

        // ============================================================
        // MARK: 6. SPHERES APP (Priority 2 — Purple)
        // ============================================================
        let app = findOrCreateSphere(
            category: "Spheres App", name: "Spheres App", icon: "circle.grid.3x3.fill",
            color: Color(red: 0.6, green: 0.3, blue: 0.9),
            description: "Spheres v2 development — macOS productivity app",
            priorityRank: 2, existingSpheres: existingSpheres, modelContext: modelContext
        )

        addLoop(content: "Implement Gmail API integration (OAuth + email scanning)", sphere: app, importance: 2, estimatedMinutes: 240, modelContext: modelContext)
        addLoop(content: "Test Gmail OAuth flow end-to-end", sphere: app, importance: 3, estimatedMinutes: 60, modelContext: modelContext)
        addLoop(content: "Plan v2.0 feature roadmap & App Store submission", sphere: app, importance: 3, estimatedMinutes: 120, modelContext: modelContext)
        addLoop(content: "Adaptive profile evolution — verify Thompson Sampling works", sphere: app, importance: 3, estimatedMinutes: 60, modelContext: modelContext)

        // ============================================================
        // MARK: 7. HEALTH (Priority 2 — Red)
        // ============================================================
        let health = findOrCreateSphere(
            category: "Health", name: "Health", icon: "heart.fill",
            color: Color(red: 0.9, green: 0.3, blue: 0.3),
            description: "Physical wellness, exercise, rest",
            priorityRank: 2, existingSpheres: existingSpheres, modelContext: modelContext
        )

        addLoop(content: "Play basketball", sphere: health, importance: 2, estimatedMinutes: 60, isHabit: true, isRecurring: true, recurrenceType: "weekly", modelContext: modelContext)
        addLoop(content: "Exercise / gym session", sphere: health, importance: 2, estimatedMinutes: 45, isHabit: true, isRecurring: true, recurrenceType: "weekly", recurrenceDays: "1,3,5", modelContext: modelContext)
        addLoop(content: "Get 7-8 hours of sleep", sphere: health, importance: 1, estimatedMinutes: 480, isHabit: true, isRecurring: true, recurrenceType: "daily", modelContext: modelContext)
        addLoop(content: "Meal prep for the week", sphere: health, importance: 3, estimatedMinutes: 60, modelContext: modelContext)

        // ============================================================
        // MARK: 8. FINANCES (Priority 3 — Teal)
        // ============================================================
        let finances = findOrCreateSphere(
            category: "Finances", name: "Finances", icon: "dollarsign.circle.fill",
            color: Color(red: 0.2, green: 0.7, blue: 0.7),
            description: "Investment group, budgeting, scholarship management",
            priorityRank: 3, existingSpheres: existingSpheres, modelContext: modelContext
        )

        addLoop(content: "Wesleyan Investment Group — complete analyst assignment", sphere: finances, importance: 2, estimatedMinutes: 120, modelContext: modelContext)
        addLoop(content: "Review monthly budget & spending", sphere: finances, importance: 3, estimatedMinutes: 30, isRecurring: true, recurrenceType: "monthly", modelContext: modelContext)
        addLoop(content: "Track internship compensation offers & compare", sphere: finances, importance: 3, estimatedMinutes: 30, modelContext: modelContext)
        addLoop(content: "PCE Fellowship — submit for $1,200 grant on completion", sphere: finances, importance: 2, estimatedMinutes: 15, modelContext: modelContext)

        // Save everything
        try? modelContext.save()
    }
}
