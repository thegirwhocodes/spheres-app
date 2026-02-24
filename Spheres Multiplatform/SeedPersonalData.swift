//
//  SeedPersonalData.swift
//  Spheres - Smart Life Manager
//
//  Seeds personalized spheres and open loops for Naomi Ivie
//  based on Spring 2026 academic schedule, career goals, and life commitments.
//

import SwiftUI
import SwiftData

struct PersonalDataSeeder {

    /// Call once to populate the app with personalized spheres and loops.
    /// Checks AppStorage flag to prevent duplicate seeding.
    static func seedIfNeeded(modelContext: ModelContext) {
        let alreadySeeded = UserDefaults.standard.bool(forKey: "hasSeededPersonalData")
        guard !alreadySeeded else { return }

        // Clean any existing default/demo data first
        DataManager.shared.cleanupDefaultDataIfNeeded(modelContext: modelContext)

        seedAll(modelContext: modelContext)
        UserDefaults.standard.set(true, forKey: "hasSeededPersonalData")
    }

    // MARK: - Main Seed Function

    static func seedAll(modelContext: ModelContext) {
        let dm = DataManager.shared
        let cal = Calendar.current

        // Helper to make dates
        func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 23, minute: Int = 59) -> Date {
            var c = DateComponents()
            c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
            return cal.date(from: c) ?? Date()
        }

        // ============================================================
        // MARK: 1. ACADEMICS (Priority 1 — Blue)
        // ============================================================
        let academics = dm.createSphere(
            name: "Academics",
            icon: "book.fill",
            color: Color(red: 0.3, green: 0.5, blue: 0.9),
            description: "Spring 2026 coursework — 4 courses at Wesleyan",
            priorityRank: 1,
            customImageData: nil,
            modelContext: modelContext
        )

        // --- ECON 241: Money, Banking & Financial Markets ---
        let _ = dm.createLoop(content: "Study for ECON 241 Exam 1 (Prof. Imai)", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 480, modelContext: modelContext)
        dm.updateLoop(
            dm.createLoop(content: "ECON 241 Exam 1", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 90, modelContext: modelContext),
            dueDate: date(2026, 3, 2, hour: 23, minute: 59), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 241 Problem Set #5", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext),
            dueDate: date(2026, 3, 24), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 241 Problem Set #6", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext),
            dueDate: date(2026, 3, 31), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 241 Problem Set #7", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext),
            dueDate: date(2026, 4, 7), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 241 Problem Set #8", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext),
            dueDate: date(2026, 4, 14), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 241 Quiz #2", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 60, modelContext: modelContext),
            dueDate: date(2026, 4, 15), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 241 Problem Set #9", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext),
            dueDate: date(2026, 4, 21), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 241 Problem Set #10", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext),
            dueDate: date(2026, 4, 28), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 241 Final Exam (Exam 2)", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext),
            dueDate: date(2026, 5, 6), modelContext: modelContext
        )

        // --- ECON 333: Financial Intermediation & Crises ---
        dm.updateLoop(
            dm.createLoop(content: "Study for ECON 333 Exam 1 (Prof. Izumi, closed book)", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 480, modelContext: modelContext),
            dueDate: date(2026, 3, 5), modelContext: modelContext
        )
        let _ = dm.createLoop(content: "ECON 333: Confirm presentation group & topic (check with Prof. Izumi)", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 30, modelContext: modelContext)
        dm.updateLoop(
            dm.createLoop(content: "ECON 333: Email research presentation group leader", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 30, modelContext: modelContext),
            dueDate: date(2026, 3, 31), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 333 Exam 2 (closed book)", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext),
            dueDate: date(2026, 4, 23), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 333 Research Paper Presentation", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 300, modelContext: modelContext),
            dueDate: date(2026, 4, 28), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 333 Research Paper (7-8 pages, double-spaced)", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 600, modelContext: modelContext),
            dueDate: date(2026, 5, 12), modelContext: modelContext
        )

        // --- ECON 349: Economic Growth ---
        dm.updateLoop(
            dm.createLoop(content: "ECON 349 Problem Set #2 (Prof. Kuenzel)", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext),
            dueDate: date(2026, 3, 2), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 349 Problem Set #3", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext),
            dueDate: date(2026, 3, 25), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "ECON 349 Exam (in-class, FRANK 002)", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext),
            dueDate: date(2026, 3, 30), modelContext: modelContext
        )
        let _ = dm.createLoop(content: "ECON 349 Group Presentation — prepare assigned paper", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 300, modelContext: modelContext)
        dm.updateLoop(
            dm.createLoop(content: "ECON 349 Final Paper + Presentation", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 600, modelContext: modelContext),
            dueDate: date(2026, 5, 4), modelContext: modelContext
        )

        // --- QAC 386: Text Mining ---
        dm.updateLoop(
            dm.createLoop(content: "QAC 386 Homework 3", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 180, modelContext: modelContext),
            dueDate: date(2026, 4, 7, hour: 12, minute: 0), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "QAC 386 Homework 4", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 180, modelContext: modelContext),
            dueDate: date(2026, 4, 21, hour: 12, minute: 0), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "QAC 386 Homework 5", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 180, modelContext: modelContext),
            dueDate: date(2026, 4, 28, hour: 12, minute: 0), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "QAC 386 Mini Project (ProQuest & TDM Studio)", sphere: academics, importance: 2, progress: 0.0, estimatedMinutes: 360, modelContext: modelContext),
            dueDate: date(2026, 5, 4), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "QAC 386 Final Project", sphere: academics, importance: 1, progress: 0.0, estimatedMinutes: 600, modelContext: modelContext),
            dueDate: date(2026, 5, 15, hour: 17, minute: 0), modelContext: modelContext
        )

        // ============================================================
        // MARK: 2. CAREER (Priority 1 — Green)
        // ============================================================
        let career = dm.createSphere(
            name: "Career",
            icon: "briefcase.fill",
            color: Color(red: 0.2, green: 0.7, blue: 0.4),
            description: "Summer 2026 internship search — BA/Consulting/Finance",
            priorityRank: 1,
            customImageData: nil,
            modelContext: modelContext
        )

        let _ = dm.createLoop(content: "Apply to Capital One Business Analyst internship", sphere: career, importance: 1, progress: 0.0, estimatedMinutes: 90, modelContext: modelContext)
        let _ = dm.createLoop(content: "Apply to Uber data/analytics internship", sphere: career, importance: 1, progress: 0.0, estimatedMinutes: 90, modelContext: modelContext)
        let _ = dm.createLoop(content: "Apply to Stripe BA internship", sphere: career, importance: 2, progress: 0.0, estimatedMinutes: 90, modelContext: modelContext)
        let _ = dm.createLoop(content: "Apply to Robinhood operations/analytics role", sphere: career, importance: 2, progress: 0.0, estimatedMinutes: 90, modelContext: modelContext)
        let _ = dm.createLoop(content: "Reach out to Wesleyan alumni in consulting (McKinsey, Bain, BCG)", sphere: career, importance: 2, progress: 0.0, estimatedMinutes: 60, modelContext: modelContext)
        let _ = dm.createLoop(content: "Reach out to ALA and Dartmouth Tuck Bridge network contacts", sphere: career, importance: 2, progress: 0.0, estimatedMinutes: 60, modelContext: modelContext)
        let _ = dm.createLoop(content: "Practice case interviews — work through McKinsey & Bain guides", sphere: career, importance: 2, progress: 0.0, estimatedMinutes: 240, modelContext: modelContext)
        let _ = dm.createLoop(content: "Tailor resume for each target company (BA vs. Finance vs. Consulting)", sphere: career, importance: 2, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext)
        let _ = dm.createLoop(content: "Follow up on submitted applications", sphere: career, importance: 2, progress: 0.0, estimatedMinutes: 30, modelContext: modelContext)
        let _ = dm.createLoop(content: "Research OPT/CPT sponsorship requirements for target companies", sphere: career, importance: 3, progress: 0.0, estimatedMinutes: 60, modelContext: modelContext)
        let _ = dm.createLoop(content: "Apply to Goldman Sachs / JP Morgan summer analyst roles", sphere: career, importance: 2, progress: 0.0, estimatedMinutes: 90, modelContext: modelContext)
        let _ = dm.createLoop(content: "Update LinkedIn profile with Beza Fintech internship details", sphere: career, importance: 3, progress: 0.0, estimatedMinutes: 30, modelContext: modelContext)

        // ============================================================
        // MARK: 3. FAITH (Priority 1 — Gold)
        // ============================================================
        let faith = dm.createSphere(
            name: "Faith",
            icon: "cross.fill",
            color: Color(red: 0.85, green: 0.7, blue: 0.3),
            description: "Spiritual growth, church, prayer, evangelism",
            priorityRank: 1,
            customImageData: nil,
            modelContext: modelContext
        )

        // Recurring daily prayer
        let prayer = dm.createLoop(content: "Daily prayer & devotional time", sphere: faith, importance: 1, progress: 0.0, estimatedMinutes: 20, modelContext: modelContext)
        prayer.isHabit = true
        prayer.isRecurring = true
        prayer.recurrenceType = "daily"
        prayer.recurrenceInterval = 1
        dm.updateLoop(prayer, modelContext: modelContext)

        // Recurring weekly church
        let church = dm.createLoop(content: "Attend The Oasis Wesleyan service", sphere: faith, importance: 1, progress: 0.0, estimatedMinutes: 90, modelContext: modelContext)
        church.isRecurring = true
        church.recurrenceType = "weekly"
        church.recurrenceInterval = 1
        church.recurrenceDays = "7" // Sunday
        dm.updateLoop(church, modelContext: modelContext)

        // Weekly prayer calendar
        let prayerCal = dm.createLoop(content: "Prayer calendar check-in", sphere: faith, importance: 2, progress: 0.0, estimatedMinutes: 15, modelContext: modelContext)
        prayerCal.isRecurring = true
        prayerCal.recurrenceType = "weekly"
        prayerCal.recurrenceInterval = 1
        dm.updateLoop(prayerCal, modelContext: modelContext)

        let _ = dm.createLoop(content: "Diary of the Student Evangelist — write next entry", sphere: faith, importance: 2, progress: 0.0, estimatedMinutes: 45, modelContext: modelContext)
        let _ = dm.createLoop(content: "Scripture memorization — pick a verse for the week", sphere: faith, importance: 3, progress: 0.0, estimatedMinutes: 15, modelContext: modelContext)

        // ============================================================
        // MARK: 4. COMMUNITY (Priority 2 — Orange)
        // ============================================================
        let community = dm.createSphere(
            name: "Community",
            icon: "person.3.fill",
            color: Color(red: 0.9, green: 0.5, blue: 0.2),
            description: "PCE Fellowship, Nigerian Student Association, Education for Equality",
            priorityRank: 2,
            customImageData: nil,
            modelContext: modelContext
        )

        // PCE Fellowship
        let pceCohort = dm.createLoop(content: "PCE Social Impact Fellowship — cohort session (4:30-6 PM)", sphere: community, importance: 1, progress: 0.0, estimatedMinutes: 90, modelContext: modelContext)
        pceCohort.isRecurring = true
        pceCohort.recurrenceType = "weekly"
        dm.updateLoop(pceCohort, modelContext: modelContext)

        let pceMentor = dm.createLoop(content: "PCE mentorship session with Shiv Soin (Entrepreneur-in-Residence)", sphere: community, importance: 2, progress: 0.0, estimatedMinutes: 60, modelContext: modelContext)
        pceMentor.isRecurring = true
        pceMentor.recurrenceType = "weekly"
        dm.updateLoop(pceMentor, modelContext: modelContext)

        dm.updateLoop(
            dm.createLoop(content: "PCE Capstone Draft", sphere: community, importance: 1, progress: 0.0, estimatedMinutes: 480, modelContext: modelContext),
            dueDate: date(2026, 4, 3), modelContext: modelContext
        )
        dm.updateLoop(
            dm.createLoop(content: "PCE Final Capstone Project", sphere: community, importance: 1, progress: 0.0, estimatedMinutes: 600, modelContext: modelContext),
            dueDate: date(2026, 5, 14), modelContext: modelContext
        )

        // Other community
        let _ = dm.createLoop(content: "Wesleyan Nigerian Student Association meeting", sphere: community, importance: 2, progress: 0.0, estimatedMinutes: 60, modelContext: modelContext)
        let _ = dm.createLoop(content: "Education for Equality — next event planning", sphere: community, importance: 3, progress: 0.0, estimatedMinutes: 60, modelContext: modelContext)
        let _ = dm.createLoop(content: "Harvard-ALA Africa Innovation Symposium — follow up on connections", sphere: community, importance: 3, progress: 0.0, estimatedMinutes: 30, modelContext: modelContext)

        // ============================================================
        // MARK: 5. MUSIC (Priority 3 — Pink)
        // ============================================================
        let music = dm.createSphere(
            name: "Music",
            icon: "music.note",
            color: Color(red: 0.85, green: 0.35, blue: 0.6),
            description: "Ebony Singers, guitar, acapella",
            priorityRank: 3,
            customImageData: nil,
            modelContext: modelContext
        )

        let ebony = dm.createLoop(content: "Ebony Singers rehearsal (Mon 7:30-9 PM)", sphere: music, importance: 2, progress: 0.0, estimatedMinutes: 90, modelContext: modelContext)
        ebony.isRecurring = true
        ebony.recurrenceType = "weekly"
        ebony.recurrenceInterval = 1
        ebony.recurrenceDays = "1" // Monday
        dm.updateLoop(ebony, modelContext: modelContext)

        let _ = dm.createLoop(content: "Practice guitar — Saturday Night Live prep", sphere: music, importance: 3, progress: 0.0, estimatedMinutes: 30, modelContext: modelContext)
        let _ = dm.createLoop(content: "Learn Bawo vocal parts (alto, soprano, tenor-bass)", sphere: music, importance: 3, progress: 0.0, estimatedMinutes: 45, modelContext: modelContext)

        // ============================================================
        // MARK: 6. SPHERES APP (Priority 2 — Purple)
        // ============================================================
        let app = dm.createSphere(
            name: "Spheres App",
            icon: "circle.grid.3x3.fill",
            color: Color(red: 0.6, green: 0.3, blue: 0.9),
            description: "Spheres v2 development — macOS productivity app",
            priorityRank: 2,
            customImageData: nil,
            modelContext: modelContext
        )

        let _ = dm.createLoop(content: "Implement Gmail API integration (OAuth + email scanning)", sphere: app, importance: 2, progress: 0.0, estimatedMinutes: 240, modelContext: modelContext)
        let _ = dm.createLoop(content: "Test Gmail OAuth flow end-to-end", sphere: app, importance: 3, progress: 0.0, estimatedMinutes: 60, modelContext: modelContext)
        let _ = dm.createLoop(content: "Plan v2.0 feature roadmap & App Store submission", sphere: app, importance: 3, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext)
        let _ = dm.createLoop(content: "Adaptive profile evolution — verify Thompson Sampling works", sphere: app, importance: 3, progress: 0.0, estimatedMinutes: 60, modelContext: modelContext)

        // ============================================================
        // MARK: 7. HEALTH (Priority 2 — Red)
        // ============================================================
        let health = dm.createSphere(
            name: "Health",
            icon: "heart.fill",
            color: Color(red: 0.9, green: 0.3, blue: 0.3),
            description: "Physical wellness, exercise, rest",
            priorityRank: 2,
            customImageData: nil,
            modelContext: modelContext
        )

        let bball = dm.createLoop(content: "Play basketball", sphere: health, importance: 2, progress: 0.0, estimatedMinutes: 60, modelContext: modelContext)
        bball.isHabit = true
        bball.isRecurring = true
        bball.recurrenceType = "weekly"
        bball.recurrenceInterval = 1
        dm.updateLoop(bball, modelContext: modelContext)

        let exercise = dm.createLoop(content: "Exercise / gym session", sphere: health, importance: 2, progress: 0.0, estimatedMinutes: 45, modelContext: modelContext)
        exercise.isHabit = true
        exercise.isRecurring = true
        exercise.recurrenceType = "weekly"
        exercise.recurrenceInterval = 1
        exercise.recurrenceDays = "1,3,5" // Mon, Wed, Fri
        dm.updateLoop(exercise, modelContext: modelContext)

        let sleep = dm.createLoop(content: "Get 7-8 hours of sleep", sphere: health, importance: 1, progress: 0.0, estimatedMinutes: 480, modelContext: modelContext)
        sleep.isHabit = true
        sleep.isRecurring = true
        sleep.recurrenceType = "daily"
        dm.updateLoop(sleep, modelContext: modelContext)

        let _ = dm.createLoop(content: "Meal prep for the week", sphere: health, importance: 3, progress: 0.0, estimatedMinutes: 60, modelContext: modelContext)

        // ============================================================
        // MARK: 8. FINANCES (Priority 3 — Teal)
        // ============================================================
        let finances = dm.createSphere(
            name: "Finances",
            icon: "dollarsign.circle.fill",
            color: Color(red: 0.2, green: 0.7, blue: 0.7),
            description: "Investment group, budgeting, scholarship management",
            priorityRank: 3,
            customImageData: nil,
            modelContext: modelContext
        )

        let _ = dm.createLoop(content: "Wesleyan Investment Group — complete analyst assignment", sphere: finances, importance: 2, progress: 0.0, estimatedMinutes: 120, modelContext: modelContext)

        let budget = dm.createLoop(content: "Review monthly budget & spending", sphere: finances, importance: 3, progress: 0.0, estimatedMinutes: 30, modelContext: modelContext)
        budget.isRecurring = true
        budget.recurrenceType = "monthly"
        budget.recurrenceInterval = 1
        dm.updateLoop(budget, modelContext: modelContext)

        let _ = dm.createLoop(content: "Track internship compensation offers & compare", sphere: finances, importance: 3, progress: 0.0, estimatedMinutes: 30, modelContext: modelContext)
        let _ = dm.createLoop(content: "PCE Fellowship — submit for $1,200 grant on completion", sphere: finances, importance: 2, progress: 0.0, estimatedMinutes: 15, modelContext: modelContext)

        // Save everything
        try? modelContext.save()
    }
}
