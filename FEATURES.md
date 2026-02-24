# Spheres - Feature List

This document tracks all implemented features for testing purposes.

---

## Phase 1: Data Persistence (SwiftData)

### Sphere Management
- [x] Create new spheres with name, icon, color, description, priority
- [x] Edit existing spheres
- [x] Delete spheres (cascades to delete associated loops)
- [x] Custom image support for sphere icons
- [x] Spheres persist across app restarts
- [x] Default spheres seeded on first launch (Spiritual, Health, Family, Career, Education, Creative)

### Loop Management
- [x] Create loops with content, sphere assignment, priority, estimated time
- [x] Loops persist across app restarts
- [x] Sample loops seeded with default spheres

### Inbox Items
- [x] Inbox items persist in database
- [x] Quick capture saves to inbox

---

## Phase 2: Open Loop Management

### Loop CRUD Operations
- [x] Create new loops from sphere detail view
- [x] Edit loops (content, sphere, priority, progress, estimated time, due date)
- [x] Delete loops
- [x] Mark loops as complete/incomplete

### Loop Features
- [x] Progress tracking (0-100% via slider)
- [x] Priority levels (1-5, where 1 is highest)
- [x] Estimated time display
- [x] Due date support with calendar picker
- [x] Due date display on loop cards
- [x] Overdue indicator (red text for past due dates)
- [x] Move loops between spheres via Edit sheet

### UI/UX
- [x] Hover actions on loop cards (Delete, Edit, Start/Stop, Done)
- [x] Progress pie chart visualization
- [x] Strikethrough for completed loops
- [x] Completion checkmark in progress circle

---

## Phase 3: Inbox Processing

### Quick Capture
- [x] Global quick capture overlay (Cmd+N or button)
- [x] Text input with priority selection
- [x] Saves directly to inbox database

### Inbox View
- [x] Lists all unprocessed inbox items
- [x] Shows capture date for each item
- [x] Empty state when inbox is clear

### Processing Flow
- [x] Process inbox item to create loop
- [x] Select target sphere
- [x] Set priority during processing
- [x] Delete inbox items
- [x] Items removed from inbox after processing

---

## Phase 4: Progress Tracking

### Time Tracking
- [x] Start/stop timer on any loop
- [x] Timer persists if app closes while running
- [x] Time spent displayed on loop cards (hourglass icon)
- [x] Active timer indicator (timer icon, accent color)
- [x] Real-time timer display updates every second
- [x] Timer auto-stops when loop marked complete
- [x] Total time tracked shown in Home view stats

### Habit/Streak Tracking
- [x] Mark any loop as a "recurring habit"
- [x] Streak counter increments on consecutive daily completions
- [x] Streak resets if day is missed
- [x] Flame icon with streak count on habit loops
- [x] "Active Streaks" section in Home view
- [x] Streak display in Edit Loop sheet

### Progress Statistics (Home View)
- [x] "Completed this week" count (real data)
- [x] "Open loops" count (real data)
- [x] "High priority" count (priority 1-2, real data)
- [x] "Time tracked" total (when > 0)
- [x] Dynamic greeting based on time of day

### Resurfacing
- [x] Shows high-priority items that are oldest
- [x] Up to 5 items displayed
- [x] Shows sphere color and name
- [x] Shows days since creation

---

## Phase 5: AI Integration

### AI Service Setup
- [x] Claude API integration (claude-3-haiku model)
- [x] API key stored securely in UserDefaults
- [x] Settings sheet for API key configuration
- [x] Connection status indicator (green dot when configured)
- [x] Graceful fallback when no API key

### Inbox AI Classification
- [x] AI suggests which sphere an inbox item belongs to
- [x] Sparkles icon indicates AI suggestion
- [x] Suggested sphere auto-selected
- [x] Highlighted border on suggested sphere option
- [x] Loading indicator while AI processes

### Smart Resurfacing (Home View)
- [x] AI-powered resurfacing with reasons
- [x] Considers: priority, age, progress, due dates
- [x] Reasons displayed with sparkles icon
- [x] Falls back to local algorithm without API key
- [x] Loading indicator while fetching suggestions

### Pattern Recognition
- [x] AI can suggest new spheres based on unassigned tasks
- [x] Analyzes task content for patterns
- [x] Returns sphere name, icon suggestion, description

### Conversational Mind View
- [x] Full chat interface with Claude
- [x] Context-aware (knows spheres, loops, completion stats)
- [x] Message history within session
- [x] Quick prompt suggestions for new users
- [x] Typing/thinking indicator
- [x] Auto-scroll to latest message
- [x] Submit via Enter key or send button
- [x] User and AI message bubbles with avatars
- [x] Welcome state when no messages
- [x] Prompts to add API key if not configured

### AI Settings
- [x] Accessible from Mind view (gear icon)
- [x] Secure text field for API key
- [x] Save/Cancel/Remove key options
- [x] Link to get API key from Anthropic

---

## Phase 6: Calendar & Scheduling

### Calendar Integration
- [x] EventKit integration for Apple Calendar
- [x] Google Calendar sync (via macOS Internet Accounts)
- [x] Calendar access permission request
- [x] Fetch events for selected day
- [x] Google Calendar detection and indicator
- [x] Support for both Apple and Google calendars

### Schedule View
- [x] New "Schedule" tab in sidebar
- [x] Date navigation (prev/next day, "Today" button)
- [x] 24-hour timeline view
- [x] Calendar events displayed in timeline
- [x] Event cards with title, time, duration
- [x] Google Calendar indicator on synced events
- [x] Color-coded events by calendar

### Time Blocking
- [x] "Loops to Schedule" sidebar in Schedule view
- [x] Shows high-priority and due-today loops
- [x] Hover to reveal schedule button
- [x] Time Block creation sheet
- [x] Start time picker (date and time)
- [x] Duration presets (15m, 30m, 60m, 90m, 120m)
- [x] Option to add to Google Calendar
- [x] Event created in selected calendar app

### Recurring Tasks
- [x] "Recurring task" toggle in Edit Loop sheet
- [x] Recurrence types: Daily, Weekly, Monthly
- [x] Custom interval (every X days/weeks/months)
- [x] Next occurrence calculated automatically
- [x] Recurrence description displayed on loops
- [x] Next occurrence scheduled on completion

---

## Phase 7: Sync & Export

### Export
- [x] Export all data to JSON (save panel)
- [x] Export loops to CSV (save panel)
- [x] JSON includes spheres, loops, inbox items
- [x] CSV includes all loop fields with headers
- [ ] iCloud sync (requires Apple Developer subscription)

### Backup & Restore
- [x] Create backup to Documents folder
- [x] Timestamped backup filenames
- [x] Restore from backup file (file picker)
- [x] Confirmation dialog before restore
- [x] Full data restore (spheres, loops, inbox)

---

## Phase 8: Polish & Enhancements

### Keyboard Shortcuts
- [x] Cmd+N: Quick Capture
- [x] Cmd+1: Home
- [x] Cmd+2: Spheres
- [x] Cmd+3: Schedule
- [x] Cmd+4: Inbox
- [x] Cmd+5: Mind
- [x] Cmd+,: Settings

### Menu Bar
- [x] Menu bar icon (circle.grid.2x2.fill)
- [x] Open Spheres from menu bar
- [x] Quick Capture from menu bar
- [x] Quit from menu bar

### Notifications
- [x] Notification permission request on launch
- [x] Due date reminders (1 hour before)
- [x] Daily habit reminders (morning)
- [x] Cancel notifications when loops deleted
- [x] Foreground notification handling

### Onboarding
- [x] First-launch onboarding overlay
- [x] 4-page walkthrough (Welcome, Capture, AI, Calendar)
- [x] Page dots navigation
- [x] Skip/Back/Next/Get Started buttons
- [x] "Show Onboarding" reset in Settings

### Settings View
- [x] New "Settings" tab in sidebar
- [x] AI API key configuration
- [x] Export JSON button with save panel
- [x] Export CSV button with save panel
- [x] Create Backup button
- [x] Restore Backup with file picker
- [x] Keyboard shortcuts reference
- [x] App version info
- [x] Show Onboarding reset button

---

## UI Components

### Navigation
- [x] Sidebar with Home, Spheres, Schedule, Inbox, Mind, Settings sections
- [x] Opaque sidebar background (no content bleed-through)
- [x] Back button with expanded hit area
- [x] Smooth transitions between views

### Theme (SpheresTheme)
- [x] Dark mode optimized
- [x] Consistent color palette
- [x] Accent color for interactive elements
- [x] Surface/background hierarchy

### Button Styles
- [x] AccentButtonStyle (primary actions)
- [x] GhostButtonStyle (secondary actions)
- [x] SmallAccentButtonStyle (inline primary)
- [x] SmallGhostButtonStyle (inline secondary)
- [x] IconButtonStyle (icon-only buttons)
- [x] TinyIconButtonStyle (small icon buttons)

### Cards & Lists
- [x] SphereCard with hover effects
- [x] DetailLoopCard with actions
- [x] InboxItemRow with actions
- [x] StatCard for metrics display
- [x] ResurfaceItem cards

### Sheets/Modals
- [x] AddSphereSheet
- [x] EditSphereSheet
- [x] AddLoopSheet
- [x] EditLoopSheet
- [x] ProcessInboxSheet
- [x] AISettingsSheet
- [x] QuickCaptureOverlay

---

## Data Models

### SphereModel
- id: UUID
- name: String
- icon: String (SF Symbol name)
- customImageData: Data? (optional custom image)
- sphereDescription: String
- priorityRank: Int
- createdDate: Date
- colorRed/Green/Blue: Double (color components)
- loops: [OpenLoopModel] (relationship)

### OpenLoopModel
- id: UUID
- content: String
- importance: Int (1-5)
- progress: Double (0.0-1.0)
- estimatedMinutes: Int?
- createdDate: Date
- isCompleted: Bool
- dueDate: Date?
- timeSpentSeconds: Int
- timerStartDate: Date?
- completedDate: Date?
- isHabit: Bool
- lastCompletedDate: Date?
- currentStreak: Int
- isRecurring: Bool
- recurrenceType: String
- recurrenceInterval: Int
- recurrenceDays: String
- nextOccurrence: Date?
- sphere: SphereModel? (relationship)

### InboxItemModel
- id: UUID
- content: String
- capturedDate: Date
- suggestedSphereId: UUID?
- isProcessed: Bool

---

## Testing Checklist

### Basic Flow
- [ ] App launches without crash
- [ ] Default spheres appear on first launch
- [ ] Can create a new sphere
- [ ] Can create a loop in a sphere
- [ ] Can quick capture to inbox
- [ ] Can process inbox item to loop
- [ ] Data persists after app restart

### Timer Testing
- [ ] Start timer on loop
- [ ] Timer display updates in real-time
- [ ] Stop timer, time is saved
- [ ] Complete loop while timer running (timer stops)
- [ ] Time persists after app restart

### Habit Testing
- [ ] Enable habit on a loop
- [ ] Complete habit, streak becomes 1
- [ ] Next day: complete again, streak becomes 2
- [ ] Miss a day: streak resets

### AI Testing (requires API key)
- [ ] Add API key in Mind settings
- [ ] Green dot appears indicating connection
- [ ] Process inbox item: AI suggests sphere
- [ ] Home view: AI resurfacing shows reasons
- [ ] Mind view: Can chat with AI
- [ ] AI responses are context-aware

### Calendar Testing
- [ ] Grant calendar access when prompted
- [ ] Calendar events appear in timeline
- [ ] Google Calendar events show (if synced via macOS)
- [ ] Create time block for a loop
- [ ] Time block appears in calendar app

### Recurring Task Testing
- [ ] Enable recurring on a loop
- [ ] Select recurrence type (daily/weekly/monthly)
- [ ] Set interval (every X days/weeks/months)
- [ ] Complete recurring loop
- [ ] Next occurrence is scheduled

### Export/Backup Testing
- [ ] Export JSON: save panel opens, file saves correctly
- [ ] Export CSV: save panel opens, file opens in Excel/Numbers
- [ ] Create Backup: success message appears
- [ ] Restore Backup: file picker opens, data restores

### Keyboard Shortcuts Testing
- [ ] Cmd+N opens Quick Capture
- [ ] Cmd+1 through Cmd+5 switch tabs
- [ ] Cmd+, opens Settings

### Menu Bar Testing
- [ ] Menu bar icon visible
- [ ] "Open Spheres" brings app to front
- [ ] "Quick Capture" opens capture overlay
- [ ] "Quit Spheres" exits app

### Onboarding Testing
- [ ] First launch shows onboarding
- [ ] Can navigate through all 4 pages
- [ ] Skip button closes onboarding
- [ ] "Get Started" closes and marks complete
- [ ] "Show Onboarding" in Settings resets it

---

*Last updated: Phase 7 & 8 completion*
