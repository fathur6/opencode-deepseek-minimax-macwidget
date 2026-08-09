# Roadmap: OpenCode macOS Usage Widget

## Overview

This milestone extends the menu bar widget's ChatGPT Plus quota card into a live reset timeline. The card does **not exist on `main`** — it lives on the unmerged `origin/feature/openai-quota` branch, so the journey starts by porting that verified data layer (fetcher, model, auth, card wiring). From there we add a pure, testable 168h-cycle math struct, then the user-specified usage bar with a moving vertical marker (driven by `TimelineView`, not the 900s refresh timer), and finally the lifecycle polish that keeps readings accurate and resilient across sleep, App Nap, and failed refreshes. Each phase depends strictly on the previous: data → math → UI → lifecycle.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3, 4): Planned milestone work
- Decimal phases (x.y): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Port OpenAI Quota Data Layer** - Merge the existing `feature/openai-quota` branch into `main`: fetcher, dual-window model, codex auth, card wiring
- [ ] **Phase 2: Reset Timeline Computation** - Pure `QuotaResetTimeline` struct computing marker position from `(reset_at, now)` with display-only rounding and clamps
- [ ] **Phase 3: Usage Bar & Marker UI** - Monochrome usage bar between % label and reset row, moving vertical marker, reset readout with time of day
- [ ] **Phase 4: Lifecycle & Polish** - Stale-value resilience, render-time ticker correctness across sleep/App Nap, legibility

## Phase Details

### Phase 1: Port OpenAI Quota Data Layer
**Goal**: The app reads ChatGPT Plus quota and reset time live from the server, ported from `origin/feature/openai-quota` (the card exists on that branch, not on `main`).
**Mode**: mvp
**Depends on**: Nothing (first phase)
**Requirements**: QUOTA-01, QUOTA-02, QUOTA-03
**Success Criteria** (what must be TRUE):
  1. User sees a ChatGPT Plus quota card in the widget menu showing live remaining % decoded from `wham/usage` (previously absent from `main`; the branch is merged, not re-derived).
  2. User sees the reset readout from `secondary_window.reset_at` including time of day (e.g. "3:08 PM"), not just the date.
  3. Both quota windows decode with Codable (5h `primary_window`, 7d/168h `secondary_window`) without failure; a missing/malformed `primary_window` never crashes the card because the readout anchors to `secondary_window`.
  4. When the `~/.codex/auth.json` token is missing or expired (401), the card falls back to last-known cached values instead of blanking.
  5. Build passes after the port: `cd opencode-widget && xcodegen generate && xcodebuild -scheme OpencodeWidgetApp -configuration Debug build` compiles, and the branch's `MenuContentTests`/`OpenAIQuotaFetcherTests` pass.
**Plans**: TBD
**UI hint**: yes

### Phase 2: Reset Timeline Computation
**Goal**: A pure, unit-testable `QuotaResetTimeline` struct in the shared layer computes the 168h-cycle marker position from `(resetDate, now)` — rounding only at display, values clamped 0...168.
**Mode**: mvp
**Depends on**: Phase 1
**Requirements**: TIME-01, TIME-02, TIME-03, TIME-04
**Success Criteria** (what must be TRUE):
  1. Remaining percent always equals `100 − secondary_window.used_percent` (the existing "99% remaining" convention is preserved, not flipped to %-used).
  2. Given a fixed `resetDate` and injected `now`, the struct returns marker position = `168 − rounded remaining hours`, clamped to 0...168 (0h → 0, 84h → 0.5 fraction, ≥168h → clamped 1.0).
  3. Cycle start derives from the server-anchored `reset_at` (never local `Date + 604800` arithmetic), so a DST transition mid-cycle produces no jump in marker position.
  4. `OpencodeWidgetSharedTests` pass against fixed `Date` fixtures covering 0h, 84h, ≥168h, and clock-skew (pre-reset) cases.
**Plans**: TBD

### Phase 3: Usage Bar & Marker UI
**Goal**: User sees a monochrome usage bar with a moving vertical marker inside the ChatGPT Plus card, positioned between the "% remaining" label and the reset row, with the reset readout extended to time of day.
**Mode**: mvp
**Depends on**: Phase 2
**Requirements**: UIUX-01, UIUX-02, UIUX-03, UIUX-04
**Success Criteria** (what must be TRUE):
  1. User sees the usage bar at the specified position: below the "% remaining" label and above the "Reset Aug 15" row inside the OpenAI card.
  2. The bar fills proportional to usage — at 99% remaining it shows ≈1% fill ("≈1% glow") — styled consistently with the existing B&W monochrome design (low-opacity track, primary-color fill).
  3. User sees a thin vertical marker on the bar whose position tracks elapsed hours in the 168h cycle and updates once per minute (`TimelineView(.periodic(by: 60))`) while the menu is open — with no network refresh required.
  4. Reset readout shows time of day in the local timezone (e.g. "Reset Aug 15, 3:08 PM"); the "3.08 pm" dot-format choice is confirmed with the user.
**Plans**: TBD
**UI hint**: yes

### Phase 4: Lifecycle & Polish
**Goal**: The reset timeline stays accurate and resilient across menu bar lifecycle events — sleep, App Nap, refresh failures — and last-known values persist.
**Mode**: mvp
**Depends on**: Phase 3
**Requirements**: UIUX-05
**Success Criteria** (what must be TRUE):
  1. A failed refresh (401 expired token, network down, endpoint drift) never blanks the card: the user keeps seeing the last-known remaining % and reset time.
  2. After the Mac sleeps or the menu closes and reopens, the marker recomputes from the wall clock at render time — the user sees the correct position immediately, without waiting up to 15 minutes for the next refresh.
  3. The marker updates at most once per minute — no second-by-second redraw churn in the menu bar.
  4. The bar and marker remain legible in both light and dark system appearance, preserving the monochrome aesthetic.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Port OpenAI Quota Data Layer | TBD | Not started | - |
| 2. Reset Timeline Computation | TBD | Not started | - |
| 3. Usage Bar & Marker UI | TBD | Not started | - |
| 4. Lifecycle & Polish | TBD | Not started | - |
