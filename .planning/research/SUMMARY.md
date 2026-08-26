# Project Research Summary

**Project:** OpenCode macOS Usage Widget
**Domain:** macOS menu bar usage widget tracking LLM provider quotas
**Researched:** 2026-08-09
**Confidence:** HIGH (stack/architecture) / MEDIUM (features, undocumented endpoint stability)

## Executive Summary

This project is a SwiftUI macOS 14+ menu bar app that shows LLM provider usage at a glance. The milestone adds an OpenAI/ChatGPT Plus quota-reset timeline: reading the next refresh date AND time, a usage bar that fills proportional to usage (≈1% in the sample state), and a moving vertical marker showing elapsed hours in the 168-hour (7-day) reset cycle.

Research confirms the data source: the undocumented `GET https://chatgpt.com/backend-api/wham/usage` endpoint returns both a 5-hour `primary_window` and a 7-day/168-hour `secondary_window`, each with `used_percent` and an absolute `reset_at` timestamp. Auth mirrors the existing OpenCode pattern — read `~/.codex/auth.json` `tokens.access_token` and send `Authorization: Bearer <token>`. This means the "99% remaining" maps to `100 − secondary_window.used_percent`, and the reset date/time comes straight from the server's `reset_at`, not local calendar arithmetic. The critical architectural discovery: **the ChatGPT Plus card already exists as code on the unmerged `origin/feature/openai-quota` branch** (with `OpenAIQuotaFetcher.swift`, an `OpenAIQuota` model, `readOpenAICredentials`, and card wiring) — the milestone must port/merge that branch rather than re-derive the approach.

The key risk is the undocumented endpoint's stability (schema or auth changes silently break reads) and the marker's novelty (no competitor renders a position-marker-on-quota-bar, so its visual form needs user acceptance). Both are mitigated by Codable decoding, stale-value persistence, and isolating the fetcher.

## Key Findings

### Recommended Stack

Use the existing XcodeGen single-target app structure (`Sources/OpencodeWidgetApp`). Fetch quota via `wham/usage` with OAuth polling of `~/.codex/auth.json` (mirrors the branch's `d506519` approach). Decode both windows with Codable; anchor reset-time math to the server `reset_at` (never local `Date + 604800`, which drifts across DST). Drive the marker with `TimelineView(.periodic(by: 60))` or an async minute ticker — the marker is a pure function of `(resetDate, now)` and needs no network refresh.

**Core technologies:**
- `wham/usage` endpoint (undocumented, verified by 3 independent 2026 implementations) — authoritative reset time + % — HIGH confidence
- OAuth bearer token from `~/.codex/auth.json` — mirrors existing OpenCode auth pattern — HIGH confidence
- Codable decode + stale-while-revalidate caching — survives undocumented API drift — HIGH confidence
- `TimelineView(.periodic(by: 60))` / minute ticker — updates marker/countdown without touching the 900s network timer — HIGH confidence
- Pure `QuotaResetTimeline` struct in the shared layer — SwiftUI-free, unit-testable cycle math — HIGH confidence

### Expected Features

**Must have (table stakes):**
- Reset date AND time readout ("Reset Aug 15, 3:08 PM") — critical path; everything hangs off it
- Percent remaining label (existing "99% remaining" convention is correct — don't flip to %-used)
- Usage bar positioned between % label and reset row (user-specified)
- Stale-data resilience — a failed refresh never blanks a reading; persist last-known values

**Should have (competitive):**
- Moving vertical marker on the bar = elapsed hours in the 168h cycle (differentiating; no competitor renders this)
- Both countdown forms are table stakes in the category (relative + absolute)

**Defer (v2+):**
- Threshold notifications (85%/95% used), pace-projection text, 7-day local trend from opencode.db, WidgetKit extension

### Architecture Approach

The card lives in `Sources/OpencodeWidgetApp` (MenuContent within `OpencodeWidgetApp.swift`), one XcodeGen target. `OpencodeUsageTrackerApp` is a separate SwiftPM executable NOT compiled into the menu bar app — do not import its components. The quota model belongs in `OpencodeWidgetShared/Models.swift` (part of persisted `WidgetCache`); timeline math as a pure `QuotaResetTimeline` struct alongside it. Data flow: Timer (900s) → DataFetcher → DataStore → MenuBarState → MenuContent; marker reads `context.date` from `TimelineView`.

**Major components:**
1. `OpenAIQuotaFetcher` — fetch + Codable decode of both windows (port from branch)
2. `OpenAIQuota` model in Shared — persisted `remainingPercent` + `resetDate` (+ `resetAt` raw) 
3. `QuotaResetTimeline` — pure cycle math: `elapsedFraction(at:)`, clamped 0...168h
4. `QuotaResetBar` component — `TimelineView` + `GeometryReader` marker, inserted between % label and reset row

### Critical Pitfalls

1. **Anchor to server `reset_at`, never `Date + 604800`** — DST drifts; use the Calendar API. (Pitfall #1, phase 1)
2. **Round only at display, clamp 0...168** — rounding remaining-hours before elapsed injects ±1h error, saturates the marker early, jitters at hour boundaries. (Pitfall #2, phase 2)
3. **Silent failure on schema change** — `JSONSerialization` string-coercion returns nil → "99% remaining forever". Use Codable + explicit fetch-state. (Pitfall #4, phase 1)
4. **Menu bar apps are App Nap targets** — timers throttle and tick-count drifts across sleep; countdowns must be pure functions of `Date.now` at render. (Pitfall #5, phase 4)
5. **Two windows exist; the prior branch dropped one** — wrong-window reads match neither ChatGPT's UI nor the 7-day model; expose both windows and anchor the readout to `secondary_window`. (Pitfall #6, phase 1)

## Implications for Roadmap

### Phase 1: Port OpenAI quota data layer
**Rationale:** Everything depends on the branch's fetcher/model/auth; it's already written and tested.
**Delivers:** `OpenAIQuotaFetcher`, `OpenAIQuota` (both windows), `readOpenAICredentials`, card wiring merged from `origin/feature/openai-quota`.
**Addresses:** reset date+time readout critical path.
**Avoids:** Pitfalls 1, 4, 6 (server-anchored reset, Codable, both windows).

### Phase 2: Reset timeline computation
**Rationale:** Pure logic, no UI — smallest testable unit after the data lands.
**Delivers:** `QuotaResetTimeline` with `elapsedFraction`, display-only rounding, clamps.
**Avoids:** Pitfall 2 (rounding/clamp errors).

### Phase 3: Usage bar + marker UI
**Rationale:** Requires data (P1) and math (P2); user-specified position between % label and reset row.
**Delivers:** `QuotaResetBar` component with fill = usage %, `TimelineView` marker = hours elapsed; reset text extended with time.
**Avoids:** Pitfall 3 (dual-axis UX legibility).

### Phase 4: Lifecycle & polish
**Rationale:** Menu bar lifecycle behavior is the last-mile concern.
**Delivers:** render-time ticker, stale-value surfacing, dark-mode/legibility verification.
**Avoids:** Pitfall 5 (App Nap, sleep drift).

### Phase Ordering Rationale
- Data → math → UI → lifecycle: strict dependency chain (each phase needs the previous).
- Port-first avoids duplicating existing verified work on the branch.
- Pure math before UI makes the bar trivially testable and drives the design.

### Research Flags
- **Phase 1:** needs API research — verify `wham/usage` responds for a Plus account that has never used Codex; `reset_at` field type (Int vs Double) decode tolerance.
- **Phase 3:** needs UI research — the marker composition is novel (no precedent); user acceptance validation required.

Phases with standard patterns (skip research-phase):
- **Phase 2:** pure Swift struct math, fully specified by formula.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Endpoint/auth/schema verified across 3 independent 2026 implementations + prior in-repo branch |
| Features | MEDIUM | Core conventions corroborated by 3+ sources; marker-novelty is inference from absence |
| Architecture | HIGH | Verified against branch code, project.yml, Package.swift, and tests |
| Pitfalls | HIGH | DST/Calendar from Apple docs + WWDC; lifecycle from Apple Energy Guide; rounding from code analysis |

**Overall confidence:** HIGH (with MEDIUM on undocumented endpoint stability and marker design)

### Gaps to Address
- `wham/usage` behavior for never-used-Codex Plus accounts — verify against real account; 401/cached-fallback covers it.
- Marker visual form — no precedent; validate with user during discussion (this phase).
- Locale "3.08 pm" dot-format — design decision; confirm desired format.
- Branch's `LSUIElement`/`.accessory` (no dock icon) change — confirm intended for this milestone.

## Sources

### Primary (HIGH confidence)
- `chatgpt.com/backend-api/wham/usage` — verified in withLinda/CodexPlusBar (Swift), liamlai88/ai-usage-bar (Python), and in-repo `origin/feature/openai-quota`
- Apple docs — Calendar/DST guidance (WWDC21), Energy Guide (App Nap/timers)
- In-repo code — project.yml, Package.swift, OpencodeWidgetApp.swift, DataFetcher.swift, Models.swift

### Secondary (MEDIUM confidence)
- jdhodges/cline sources — weekly cap/168h model
- CodexBar (19.8k★), TokenBar, minimax-usage-checker — feature conventions and reset-countdown norms
- knightli.com, openai/codex#10869, DeepWiki — wham endpoint semantics cross-check

### Tertiary (LOW confidence)
- dashboard/billing deprecation timing — irrelevant to implementation

---
*Research completed: 2026-08-09*
*Ready for roadmap: yes*
