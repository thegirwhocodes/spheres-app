# Smart Setup: AI-Powered Sphere Auto-Population from Mac Ecosystem

## Context
Spheres currently seeds 6 hardcoded default spheres (Spiritual, Health, Family, etc.) with fake sample tasks. This feels generic and requires manual work. The startup-grade vision: user opens app, grants permissions, and AI scans their **entire Mac ecosystem** (Calendar, Mail, Notes, Reminders, Voice Memos, iMessage) to automatically create personalized spheres and tasks that reflect their *actual* life.

**The good news:** 95% of the infrastructure already exists. There are working SourceAdapters for 5+ data sources, a Claude API integration, confidence scoring, and a task extraction pipeline. We're building the orchestration layer on top.

## What Already Exists (Reuse Everything)

| Component | File | Status |
|-----------|------|--------|
| Reminders adapter | `SourceAdapters/RemindersAdapter.swift` | Working |
| Notes adapter | `SourceAdapters/NotesAdapter.swift` | Working |
| Mail adapter | `SourceAdapters/AppleMailAdapter.swift` | Working |
| Voice Memos adapter | `SourceAdapters/VoiceMemosAdapter.swift` | Working |
| iMessage adapter | `SourceAdapters/IMessageAdapter.swift` | Working (needs Full Disk Access) |
| Adapter manager | `SourceAdapters/SourceAdapter.swift` | Working |
| Calendar service | `CalendarService.swift` | Working |
| Claude API | `AIService.swift` | Working (Haiku 3) |
| Task extraction + confidence | `OpenLoopExtractor.swift` | Working |
| Personalization | `PersonalizationService.swift` | Working |
| Adaptive profile | `AdaptiveProfileService.swift` | Working |

## The Plan

### Phase 1: Remove Default Spheres + Clean Slate

**Files:** `DataManager.swift`, `ContentView.swift`

1. Remove `seedDefaultSpheres()` — no more hardcoded Spiritual/Health/Family/etc.
2. Remove `addSampleLoops()` entirely (already neutered, finish the job)
3. Add `hasUsedSmartSetup` flag so DataManager knows not to seed defaults
4. Delete any existing default spheres on launch (one-time cleanup, similar to the sample loops cleanup we just did)

### Phase 2: Create `SmartSetupService.swift` (The Brain)

New file — orchestrates the entire scan + AI analysis.

**Flow:**
```
1. Check which sources user enabled
2. For each enabled source: call adapter.extractTasks(since: 30 days ago, limit: 100)
3. Fetch 30 days of calendar events via CalendarService
4. Summarize calendar into categories (pure Swift, no AI needed)
5. Aggregate all data into a structured payload (~3000 tokens)
6. Send to Claude Sonnet with sphere generation prompt
7. Parse JSON response into GeneratedSphere + GeneratedTask structs
8. Return to UI for user review
```

**Key design:**
- `@MainActor class SmartSetupService: ObservableObject` (matches all other services)
- Published properties: `scanPhase`, `scanProgress`, `currentSourceLabel`, `aiGeneratedSetup`
- Uses **Claude Sonnet** for the one-time heavy reasoning (~$0.04 per onboarding)
- Summarizes data before sending (calendar categories, not raw events)

**AI Prompt Strategy:**
- System prompt: "Analyze this user's digital footprint. Create 4-8 personalized spheres."
- Require JSON response with: sphere name, icon (SF Symbol), color (RGB), description, priority, tasks
- Key instruction: "Name spheres specifically — 'PhD Research' not 'Education', 'Marathon Training' not 'Health'"
- Include list of valid SF Symbol names so AI picks real ones

**Token budget:** ~3800 tokens input + ~2000 tokens output = ~$0.04/user. Very cheap.

### Phase 3: Create `SmartSetupOnboardingFlow.swift` (The UI)

New file — replaces the 10-step `UnifiedOnboardingFlow` with 4 steps:

| Step | What Happens | UI |
|------|-------------|-----|
| **1. Welcome** | Name + API key (if not set) | Clean input fields, "Let's organize your life" |
| **2. Permissions** | Toggle which sources to scan | Toggle cards for each source with live permission status |
| **3. AI Scan** | Animated progress while scanning | Source icons animate as they complete, progress bar, "Analyzing..." |
| **4. Review** | Show generated spheres + tasks | Grid of sphere cards, expandable to show tasks, toggle on/off, edit names |

**Fallbacks:**
- Very little data (<5 items): Show "Lightweight Setup" with template spheres from LifeArea enum
- No API key: Skip AI, offer manual sphere creation
- Permission denied: Proceed with whatever was granted
- AI parsing failure: Retry once, then fall back to keyword-based grouping

### Phase 4: Extend `AIService.swift`

Small changes to support Sonnet + structured prompts:

1. Add `model` parameter to `sendMessage()` (default stays Haiku for backward compat)
2. Add `system` prompt support in API body construction
3. Add `sendStructuredMessage()` for JSON-mode requests

### Phase 5: Add Calendar Summarization to `CalendarService.swift`

New method `summarizeRecentActivity(days: 30) -> String`:
- Groups events by title keywords
- Counts frequency and typical times
- Returns human-readable summary: "Work meetings (12/week, Mon-Fri 9-5), Gym (3/week, mornings)..."
- Pure Swift, no AI needed

### Phase 6: Wire It Up in `ContentView.swift`

1. Replace `UnifiedOnboardingFlow` reference with `SmartSetupOnboardingFlow`
2. Keep old flow accessible via Settings "Reset Onboarding" for manual setup option

## New Files

| File | Purpose | Est. Lines |
|------|---------|-----------|
| `SmartSetupService.swift` | Scan orchestration, AI prompt, JSON parsing, sphere materialization | ~400 |
| `SmartSetupOnboardingFlow.swift` | 4-step onboarding UI | ~600 |

## Modified Files

| File | Change |
|------|--------|
| `AIService.swift` | Add model param + system prompt support to `sendMessage()` (~30 lines) |
| `ContentView.swift` | Swap onboarding flow (1 line), remove default sphere seeding call |
| `DataManager.swift` | Remove `seedDefaultSpheres()`, remove `addSampleLoops()`, add smart setup flag |
| `CalendarService.swift` | Add `summarizeRecentActivity()` method (~60 lines) |

## Values Quiz Decision
- **Remove from onboarding entirely** — AI infers life domains from actual data
- **Offer after ~1 week** as a "Refine Your Profile" card on Home view
- The quiz, PersonalizationService, and AdaptiveProfileService all stay in the codebase — just deferred
- This keeps the biblical/psychological grounding as an opt-in depth layer

## Build Approach
- **Full end-to-end** — new onboarding flow + scan service + AI prompt + review UI in one pass
- The complete startup experience from day one

## Privacy Approach

- All extraction runs **locally** (AppleScript, EventKit, SQLite)
- Only **summarized** data goes to Claude API (subject lines, task titles — not full email/message bodies)
- The existing adapters already extract minimally — this is by design
- Clear disclosure in Permissions step: "A summary of your data will be sent to Anthropic's Claude AI for analysis"
- Future: on-device models when Apple's Foundation Models mature

## Re: RAG / Fine-Tuning

For v1, **prompt engineering is sufficient** — we're sending one batch of data for one-time sphere generation. No need for RAG or fine-tuning yet.

**Future (v2+):**
- **RAG**: Build local vector store of user data for richer AI context in Mind chat
- **Fine-tuning**: Not practical per-user, but could fine-tune on categorization patterns across users
- **On-device**: Apple Intelligence / Core ML for task extraction without cloud

## Implementation Status (Feb 23, 2026)

**ALL PHASES COMPLETE - BUILD SUCCEEDED**

| Phase | Status | Details |
|-------|--------|---------|
| Phase 1: Remove defaults | DONE | `DataManager.swift` — removed `seedDefaultSpheres()`, `addSampleLoops()`, added `cleanupDefaultDataIfNeeded()` |
| Phase 2: SmartSetupService | DONE | New file `SmartSetupService.swift` — full scan pipeline, AI prompt, JSON parsing, fallback |
| Phase 3: Onboarding UI | DONE | New file `SmartSetupOnboardingFlow.swift` — 4-step flow with animated scan + review |
| Phase 4: AIService extension | DONE | Added `sendStructuredMessage()`, model param, system prompt support |
| Phase 5: Calendar summary | DONE | Added `summarizeRecentActivity()` to `CalendarService.swift` |
| Phase 6: Wire up | DONE | `ContentView.swift` swapped to `SmartSetupOnboardingFlow` |
| TaskSource.calendar | DONE | Added `.calendar` case to `SourceAdapter.swift` |
| Xcode project | DONE | Both new files added to `project.pbxproj` |

### To Test Smart Setup
To trigger the new onboarding, reset the onboarding flag:
```swift
UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
```
Or use Settings → Reset Onboarding in the app.

### Next Steps (Not Yet Built)
- **AutoCategorizationService**: Ongoing background task categorization into existing spheres
- **"Refine Your Profile" card**: Values quiz offered after 1 week of usage on Home view
- **File system scanning**: NSMetadataQuery / Spotlight integration for project folders
- **On-device AI**: Apple Foundation Models when they mature

## Verification

1. Fresh app launch → SmartSetupOnboardingFlow appears (not old 10-step flow)
2. Grant permissions → sources show green checkmarks
3. Scan completes → see AI-generated spheres specific to user's actual data
4. Review → can toggle spheres/tasks, edit names
5. Approve → spheres + loops created in SwiftData
6. Home view shows personalized spheres, not generic defaults
7. Schedule view shows real tasks, not "Call mom about Thanksgiving"
