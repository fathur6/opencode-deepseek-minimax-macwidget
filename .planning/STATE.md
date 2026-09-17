---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 05
current_phase_name: settings-provider-display-preferences
status: executing
stopped_at: Completed 05-03-PLAN.md
last_updated: "2026-09-17T22:53:14.237Z"
last_activity: 2026-09-17
last_activity_desc: Phase 05 execution started
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 5
  completed_plans: 3
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-09)

**Core value:** Show the user their remaining AI budget and when it resets, at a glance from the menu bar — with zero interaction required.
**Current focus:** Phase 05 — settings-provider-display-preferences

## Current Position

Phase: 05 (settings-provider-display-preferences) — EXECUTING
Plan: 4 of 5
Status: Ready to execute
Last activity: 2026-09-17 — Phase 05 execution started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: N/A
- Total execution time: N/A

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: (none yet)
- Trend: N/A

*Updated after each plan completion*
| Phase 05 P01 | 2 min | 2 tasks | 2 files |
| Phase 05 P02 | 12min | 2 tasks | 4 files |
| Phase 05 P03 | 4min | 2 tasks | 2 files |

## Accumulated Context

### Roadmap Evolution

- Phase 5 added: Settings: Provider Display Preferences

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: The card does NOT exist on `main` — Phase 1 must port `origin/feature/openai-quota` (commits `667fefb`, `d506519`), not re-derive it.
- [Roadmap]: Anchor all reset math to server `reset_at`; never `Date + 604800` (DST safety). — Pitfall #1
- [Roadmap]: Decode both quota windows; readout anchors to `secondary_window` (7d/168h). — Pitfall #6
- [Roadmap]: Marker = pure function of `(resetDate, now)` via `TimelineView(.periodic(by: 60))`; never computed in the 900s refresh loop. — Anti-Pattern 1
- [Roadmap]: `QuotaResetTimeline` stays pure (SwiftUI-free) in `OpencodeWidgetShared`; rounding at display only, clamped 0...168. — Pitfall #2
- [Roadmap]: Do NOT import `OpencodeUsageTrackerApp` components (separate SwiftPM executable, not in the XcodeGen target). — Anti-Pattern 2
- [Roadmap]: Preserve the branch's stale-while-revalidate fallback (`previousQuota ?? fetched`).
- [Phase 05]: Typed per-provider UserDefaults Booleans default missing or malformed visibility values to visible. — Preserves default-visible behavior without storing presentation state in cache or secrets.
- [Phase 05]: ProviderCardLayout filters fixed ProviderID case order and returns an empty sequence for charts-only mode. — Preserves DeepSeek, MiniMax, OpenAI order while keeping visibility presentation-only.
- [Phase 05]: Use explicit, release-stable service and account constants for generic-password Keychain items rather than UI-derived names.
- [Phase 05]: Resolve each provider independently from Keychain first, then read only its matching legacy auth value without legacy mutation APIs.
- [Phase 05]: Use an optional ProviderCredentialResolver injection seam while constructing the Keychain-first resolver from the existing auth path in production. — This keeps production refresh behavior compatible with the existing legacy-auth path while allowing in-memory resolver fixtures that never access the host Keychain.
- [Phase 05]: Resolve DeepSeek and MiniMax once each before issuing only their selected endpoint calls; do not route card visibility into refresh. — Per-provider resolution preserves independent credential collection while retaining the existing cache, ledger, chart, and OpenAI quota data path.

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1] `wham/usage` is undocumented — schema/auth drift risk (MEDIUM confidence); Codable + stale fallback mitigates. Verify behavior for a Plus account that never used Codex (401 → cached fallback covers it).
- [Phase 1] `reset_at` field type decode tolerance (Int vs Double) needs verification during planning.
- [Phase 1] Branch's `LSUIElement`/`.accessory` change (no dock icon) — confirm intended for this milestone.
- [Phase 3] Marker visual composition is novel (no competitor precedent) — user acceptance validation required (research flag).
- [Phase 3] Locale "3.08 pm" dot-format vs "3:08 PM" — design decision to confirm with user.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Quick Tasks Completed

| ID | Description | Completed | Status |
|----|-------------|-----------|--------|
| 260816-v97 | Add and deploy 168-hour OpenAI/DeepSeek usage chart | 2026-08-16 | Complete |
| 260912-ns1 | DAF-23 add OpenAI 5-hour quota bar, preserve ledger, ship v1.3.0 | 2026-09-12 | Complete |

## Session Continuity

Last session: 2026-09-17T22:52:52.815Z
Stopped at: Completed 05-03-PLAN.md
Resume file: None
