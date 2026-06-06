# Spheres

Mac SwiftUI predecessor to Cortex. Early experiments in personal AI agents.

The "spheres" idea: your life is made of areas (sphere of work, sphere of family, sphere of health, etc.). An AI agent that knows you should be aware of all of them and route attention between them.

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
