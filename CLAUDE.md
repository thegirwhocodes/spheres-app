# Spheres Mac - Version 1.0 Dec 2025 Project Instructions

## ⚠️ COMPACTION RULE (read this first)

**If context compacted mid-conversation: STOP. Read your ENTIRE session transcript from `.claude-sessions/` BEFORE doing anything else.** Find your session ID in `.claude-sessions/INDEX.txt` (most recent entry), then read that ENTIRE `.txt` file — every line, start to finish, in chunks if needed. Do NOT just read the tail end. Do NOT assume you remember what happened earlier. Read the FULL file. A previous Claude skipped this step and gave wrong answers, duplicated already-completed work, and wasted the user's time. Another Claude read only the last 300 lines and missed critical context from earlier in the session. The SessionStart hook will remind you, but follow this rule even without the reminder.

**Be patient.** If recovery takes 5 minutes, take 5 minutes. The user would rather wait for a correct answer than get an instant wrong one. Do not let "the user is waiting" override the instructions. Every shortcut leads to wrong answers.

## ⚠️ Context Recovery — DO THIS BEFORE ANSWERING THE USER'S FIRST MESSAGE

**This is not optional. Do these steps BEFORE responding to anything the user says, even "hello."** Do NOT skip large files. Do NOT rationalize "the user's message is short so I can skip reading." Do NOT read only the small sessions and skip the big ones. Read ALL of them, fully, every line.

**About the user:** Naomi is patient. She wants you to read through ALL the context first so you don't miss anything or slow down her work later. She would rather wait 5 minutes for you to be thorough than get a fast answer that's wrong or incomplete. She will be displeased if you skip the context recovery steps or take shortcuts. Multiple previous Claudes have been called out for this — don't be the next one. - NAOMI WRITING THIS DIRECTLY HERE DO NOT TAKE ANY SHORTCUTS OR RATIONALIZE AT ANY POINT THAT A CONTEXT FILE IS TOO LONG AND GO OFF AND MAKE YOUR OWN DECISIONS READ EVERYTHIGN THOROUGHLY NO MATTER THE SITUATION I AM THE ONE WHO WROTE THIS CLAUDE.MD FILE MYSLEF I WILL KNOW IF YOU RATIONALIZE OR SKIP SO JUST DO A THOROUGH JOB OR ELSE I WILL BE ANGRY!!!!!

1. **Memory loads automatically** — check for session IDs referenced in memory files. Collect those IDs.
2. **Read `.claude-sessions/INDEX.txt`**, then read the **last 2 session transcripts** fully — EVERY line, start to finish, in chunks if needed. Do NOT stop at 2000 lines.
3. **Read memory-linked session transcripts** — any session IDs from step 1 that aren't in the last 2, read those too.
4. **Read Agent research files only** for those session IDs from `~/.claude/projects/-Users-naomiivie-Downloads-App-Spheres-Mac---Version-1-0-Dec-2025/agent-research/` — read files that do NOT start with `WebSearch_` or `WebFetch_` in the description part of the filename. Skip all WebSearch/WebFetch files — those are bulky and only needed during deep research.
5. **If context compacts mid-conversation**, re-read your current session's ENTIRE `.txt` from `.claude-sessions/`.
6. **If the user asks about something you don't recognize**, Grep for the topic across all `.claude-sessions/*.txt` files before saying you don't know. If you find matches, read those sessions and their Agent research files (not WebSearch/WebFetch).
7. **Only THEN respond to the user.** Be patient. If recovery takes 5 minutes, take 5 minutes.

## Deep Project Understanding (only when asked to "understand the project", "get up to speed", "read everything", "thorough familiarization", etc.)

All of the basic context steps above, PLUS:

4. **Read matching research files** — for ALL session IDs from steps 2 and 3, read every file in `~/.claude/projects/-Users-naomiivie-Downloads-App-Spheres-Mac---Version-1-0-Dec-2025/agent-research/` whose filename starts with those IDs. These contain full web search results and research agent outputs — the session transcripts only have summaries.
5. **Read the foundational research index** — read `~/.claude/projects/-Users-naomiivie-Downloads-App-Spheres-Mac---Version-1-0-Dec-2025/memory/FOUNDATIONAL_RESEARCH_INDEX.md`. This lists full paths to every research .txt that was created before or during major build sessions across ALL projects. Use it to find and read the original research behind any decision.
6. **Read the entire codebase** — every file, every directory. Understand the full architecture, not just the parts that seem relevant.
7. **If you still need older context**, use Grep to search across all `.claude-sessions/*.txt` files for specific topics, then pull the matching research files for those sessions too.
8. **Save what you learn** — write important architectural decisions, patterns, and context into the memory folder (with session IDs) so the next Claude doesn't have to repeat this process.

Do not take shortcuts. Do not summarize before reading. Read first, understand fully, then respond.

## Memory

Project memory files are in `~/.claude/projects/-Users-naomiivie-Downloads-App-Spheres-Mac---Version-1-0-Dec-2025/memory/`. These contain curated key decisions, user preferences, and project vision. Memory loads automatically — the session transcripts are the raw backup if you need more detail than memory provides.

### Writing memory updates

When updating memory files, put the session ID inline right next to each fact or decision. Format: `- fact or decision - session_id`. Examples:

```
- Switched from ElevenLabs to Chatterbox TTS with Naomi's voice clone - efd7d7d2
- Decided on Swift native over React Native for premium feel - e59a15e2
- LoRA training validated as feasible on consumer GPU - 296c88b8
```

This lets future Claudes trace any decision back to the exact conversation where it happened, and from there to the research .txt files that informed it.
