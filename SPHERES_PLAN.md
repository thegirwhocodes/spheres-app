# Spheres - Smart Life Manager
## App Vision & Development Plan

---

## Original Vision

**Spheres** is a Smart Life Manager macOS app designed to help users organize their life into distinct "spheres" (areas of focus like Health, Career, Family, Spiritual, etc.) and track "open loops" (tasks, thoughts, commitments) within each sphere.

### Design Philosophy
- **Dark liquid glass UI** - Modern, translucent aesthetic
- **Minimalist but functional** - Clean interface with subtle interactions
- **AI-powered companion** - Proactive insights and suggestions
- **GTD-inspired** - Capture everything, process later, organize by life area

---

## What's Currently Built (v1.0)

### Core UI Structure
- [x] Main app shell with sidebar navigation
- [x] Dark theme with SpheresTheme color system
- [x] Four main tabs: Spheres, Home, Inbox, Mind

### Spheres View
- [x] Compact card grid layout (3 columns)
- [x] Sphere cards showing:
  - Icon with gradient background
  - Name and priority rank
  - Open loop count
  - Scrollable task list with progress indicators
  - Quick View button on hover
- [x] Full page sphere detail view (click to expand)
- [x] Quick View sheet (modal)
- [x] Add Sphere sheet with:
  - Icon picker (multiple styles: Filled, Outline, Bold, Whimsical, Minimal)
  - Color picker
  - Priority rank selector (1-5, where 1 = highest)
  - Custom image upload option

### AI Insights Section
- [x] Two filled insight cards displayed in a row
- [x] Suggestion types: schedule, new sphere, resurface, insight

### Home View
- [x] Time-based greeting
- [x] "Resurfacing Today" section for important tasks
- [x] Weekly stats cards (Completed, Open Loops, High Priority)

### Inbox View
- [x] Unprocessed items list
- [x] AI classification suggestions
- [x] Process All functionality (UI)

### Mind View
- [x] Chat interface with AI companion
- [x] Message bubbles for user/AI
- [x] Text input field

### Quick Capture
- [x] Overlay modal for fast thought capture
- [x] Priority selector
- [x] Mic and camera buttons (UI only)

---

## Features To Build

### Phase 1: Data Persistence & Core Functionality
- [x] Core Data or SwiftData integration
- [x] Save/load spheres
- [x] Save/load open loops
- [x] Save/load inbox items
- [x] User preferences storage

### Phase 2: Open Loop Management
- [x] Create new open loops from any sphere
- [x] Edit existing loops (content, priority, progress)
- [x] Mark loops as complete
- [x] Delete loops
- [x] Drag to reorder loops
- [x] Move loops between spheres
- [x] Due dates (reminders not yet implemented)

### Phase 3: Inbox Processing
- [x] Add items to inbox (quick capture)
- [x] Process inbox items:
  - Assign to sphere
  - Set priority
  - Delete/archive
- [x] AI-suggested sphere classification

### Phase 4: Progress Tracking
- [x] Manual progress updates on loops
- [x] Time tracking per loop
- [x] Daily/weekly progress summaries
- [x] Streak tracking for habits

### Phase 5: AI Integration
- [x] Connect to AI API (Claude/OpenAI)
- [x] Natural language processing for inbox items
- [x] Smart resurfacing algorithm
- [x] Scheduling suggestions based on calendar (requires Phase 6)
- [x] Pattern recognition (suggesting new spheres)
- [x] Conversational interface in Mind view

### Phase 6: Calendar & Scheduling
- [x] Calendar integration (Apple Calendar + Google Calendar sync)
- [x] Time blocking for open loops
- [x] Schedule view
- [x] Recurring tasks

### Phase 7: Sync & Export
- [ ] iCloud sync (requires Apple Developer subscription — cannot implement without it)
- [x] Export data (JSON, CSV)
- [x] Backup/restore

### Phase 8: Polish & Enhancements
- [x] Keyboard shortcuts
- [x] Menu bar quick capture
- [x] Notifications (local)
- [ ] Widgets (requires Apple Developer subscription — cannot implement without it)
- [x] Onboarding flow
- [x] Settings view

---

## Current UI Specifications

### Theme Colors (SpheresTheme)
```swift
background: Color(red: 0.04, green: 0.04, blue: 0.05)
surface: Color.white.opacity(0.05)
surfaceHover: Color.white.opacity(0.08)
surfaceElevated: Color.white.opacity(0.07)
border: Color.white.opacity(0.1)
textPrimary: Color.white
textSecondary: Color.white.opacity(0.6)
textTertiary: Color.white.opacity(0.4)
textMuted: Color.white.opacity(0.25)
accent: Color(red: 0.55, green: 0.36, blue: 0.96) // Purple
```

### Sphere Card Dimensions
- Card height: 350px
- Card padding: 14px
- Corner radius: 14px
- Icon: 44px outer / 36px inner / 16pt font
- Sphere name: 15pt semibold
- Subtitle: 11pt
- Task text: 13pt (textMuted color)
- Progress ring: 20px
- Bullet: 5px, 0.4 opacity

### Priority System
- 1 = Highest priority
- 5 = Lowest priority
- Spheres sorted by priority rank (ascending)
- Loops sorted by importance within spheres

---

## Data Models

### Sphere
```swift
- id: UUID
- name: String
- icon: String (SF Symbol name)
- customImageData: Data? (for custom images)
- color: Color
- description: String
- priorityRank: Int (1-5)
- createdDate: Date
```

### OpenLoop
```swift
- id: UUID
- content: String
- sphereId: UUID?
- importance: Int (1-5, 1 = highest)
- progress: Double (0.0 to 1.0)
- estimatedMinutes: Int?
- createdDate: Date
- isCompleted: Bool
```

### AISuggestion
```swift
- id: UUID
- title: String
- description: String
- type: SuggestionType (newSphere, resurface, schedule, insight)
```

---

## Notes

- App uses mock data currently - all spheres and loops are hardcoded
- The hover animations and transitions are working well
- Priority system: 1 = highest, 5 = lowest (confirmed)
- AI Insights now display as two side-by-side filled cards

---

*Last updated: January 2026*
