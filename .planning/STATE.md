---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 05
current_phase_name: settings-provider-display-preferences
status: executing
stopped_at: Completed 05-04-PLAN.md
last_updated: "2026-09-17T23:05:28.147Z"
last_activity: 2026-09-17
last_activity_desc: Completed 05-04 native provider settings
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 5
  completed_plans: 4
  percent: 80
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-09)

**Core value:** Show the user their remaining AI budget and when it resets, at a glance from the menu bar — with zero interaction required.
**Current focus:** Phase 05 — settings-provider-display-preferences

## Current Position

Phase: 05 (settings-provider-display-preferences) — EXECUTING
Plan: 5 of 5
Status: Ready to execute
Last activity: 2026-09-17 — Completed 05-04 native provider settings

Progress: [████████░░] 80%

## Performance Metrics

**Velocity:**

- Total plans completed: 4
- Average duration: 6 min
- Total execution time: 26 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 05 | 4 | 26 min | 6 min |

**Recent Trend:**

- Last 4 plans: 2 min, 12 min, 4 min, 8 min
- Trend: Steady

*Updated after each plan completion*
| Phase 05 P01 | 2 min | 2 tasks | 2 files |
| Phase 05 P02 | 12 min | 2 tasks | 4 files |
| Phase 05 P03 | 4 min | 2 tasks | 2 files |
| Phase 05 P04 | 8 min | 2 tasks | 5 files |

## Accumulated Context

### Roadmap Evolution

- Phase 5 added: Settings: Provider Display Preferences

### Decisions

- [Roadmap]: The card does NOT exist on `main` — Phase 1 must port `origin/feature/openai-quota` (commits `667fefb`, `d506519`), not re-derive it.
- [Roadmap]: Anchor all reset math to server `reset_at`; never `Date + 604800` (DST safety).
- [Roadmap]: Decode both quota windows; readout anchors to `secondary_window` (7d/168h).
- [Roadmap]: Marker is a pure function of `(resetDate, now)` via `TimelineView(.periodic(by: 60))`; never compute it in the 900s refresh loop.
- [Roadmap]: `QuotaResetTimeline` stays pure in `OpencodeWidgetShared`; rounding occurs at display only and values clamp to 0...168.
- [Roadmap]: Preserve stale-while-revalidate quota fallback (`previousQuota ?? fetched`).
- [Phase 05]: Typed per-provider UserDefaults Booleans default missing or malformed visibility values to visible.
- [Phase 05]: ProviderCardLayout filters fixed ProviderID order and returns an empty sequence for charts-only mode.
- [Phase 05]: Use explicit, release-stable generic-password Keychain service and account constants rather than UI-derived names.
- [Phase 05]: Resolve each provider independently from Keychain first, then only its matching read-only legacy auth value.
- [Phase 05]: Inject an optional ProviderCredentialResolver seam to keep production Keychain-first while tests use in-memory fixtures.
- [Phase 05]: Resolve DeepSeek and MiniMax once each before selected endpoint calls; card visibility never affects refresh.
- [Phase 05]: Use SwiftUI Settings and SettingsLink rather than custom AppKit settings-window ownership.
- [Phase 05]: Keep candidate credentials local to validation and Keychain upsert calls; observable state contains only redacted categories.
- [Phase 05]: Make display preferences observable so Settings toggles update the already-open menu immediately while persistence remains presentation-only.

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1] `wham/usage` is undocumented — schema/auth drift risk; Codable plus stale fallback mitigates it.
- [Phase 3] Marker visual composition and locale time format require user acceptance validation.
- [Phase 05] Native Settings focus reuse and compact-scroll layout need manual macOS UAT in the final plan.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Quick Tasks Completed

| ID | Description | Completed | Status |
|----|-------------|-----------|--------|
| 260816-v97 | Add and deploy 168-hour OpenAI/DeepSeek usage chart | 2026-08-16 | Complete |
| 260912-ns1 | DAF-23 add OpenAI 5-hour quota bar, preserve ledger, ship v1.3.0 | 2026-09-12 | Complete |

## Session Continuity

Last session: 2026-09-17T23:05:28.147Z
Stopped at: Completed 05-04-PLAN.md
Resume file: None
