# Spheres

Mac SwiftUI predecessor to Cortex: a personal AI brain organized around the areas of a person's life.

The "spheres" idea: your life is made of areas (sphere of work, sphere of family, sphere of health, etc.). An AI agent that knows you should be aware of all of them and route attention between them.

## What it does

- Creates and manages life spheres, loops, inbox items, habits, streaks, and schedules.
- Uses Claude to classify inbox items, resurface neglected work, suggest schedules, and power a conversational Mind view.
- Integrates with Apple/Google Calendar through EventKit and macOS accounts.
- Stores local state with SwiftData and supports export/backup flows.
- Includes source adapters for Gmail, Apple Mail, iMessage, Notes, Reminders, and Voice Memos experiments.

## What it became

The architecture here was ported to the web for [Cortex](https://cortex-web-one.vercel.app). Five Swift services map to TypeScript modules:

```
SmartSetupService.swift     →   lib/ai/sphere-generator.ts
AIService.swift             →   lib/ai/claude.ts + query-engine.ts
MemoryService.swift         →   lib/ai/memory-extractor.ts
PersonalizationService.swift →  lib/ai/profile-builder.ts
SourceAdapter.swift         →   lib/integrations/adapter-base.ts
```

## Status

Archived — superseded by Cortex web. Kept public as the architecture record.
