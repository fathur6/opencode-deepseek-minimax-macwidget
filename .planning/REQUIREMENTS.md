# Requirements — OpenCode macOS Usage Widget

## v1 Requirements

### Quota Data (QUOTA)

- [ ] **QUOTA-01**: App reads the OpenAI/ChatGPT Plus next-reset timestamp including time of day (e.g. "3:08 PM") from the `wham/usage` `secondary_window.reset_at`, not just the date. Port from `origin/feature/openai-quota`.
- [ ] **QUOTA-02**: App decodes both quota windows (5h `primary_window`, 7d/168h `secondary_window`) with Codable; the reset readout anchors to `secondary_window`.
- [ ] **QUOTA-03**: Auth reads `~/.codex/auth.json` `tokens.access_token` as Bearer token, mirroring the existing OpenCode auth.json pattern; missing/expired token falls back to last-known cached values.

### Reset Timeline Computation (TIME)

- [ ] **TIME-01**: Remaining percent = `100 − used_percent` from `secondary_window` (displayed as "99% remaining").
- [ ] **TIME-02**: Moving vertical marker position = elapsed hours in the 168h cycle, formula `168 − rounded remaining hours before next reset`, computed from `reset_at` and wall clock at render time (no network refresh needed).
- [ ] **TIME-03**: Elapsed/hours math lives in a pure, unit-testable `QuotaResetTimeline` struct in the shared layer; rounding applied at display only; values clamped 0...168.
- [ ] **TIME-04**: Reset time is server-anchored (`reset_at` absolute timestamp); never derived via local `Date + 604800` arithmetic (DST safety).

### UI/UX (UIUX)

- [ ] **UIUX-01**: Usage bar is positioned below the "99% remaining" label and above the "Reset Aug 15" row inside the OpenAI card.
- [ ] **UIUX-02**: Bar fills proportional to usage (≈1% glow when 1% used / 99% remaining), consistent with the existing B&W monochrome design.
- [ ] **UIUX-03**: Moving vertical marker on the bar represents position in the 168h cycle; updates live via a minute-granularity clock (TimelineView) while visible.
- [ ] **UIUX-04**: Reset readout extended to include time of day (e.g. "Reset Aug 15, 3:08 PM"); confirm local timezone rendering and "3.08 pm" dot-format style.
- [ ] **UIUX-05**: Stale-data resilience — a failed refresh never blanks a reading; last-known values persist.

## v2 Requirements (deferred)

- [ ] **QUOTA-05**: Derive cycle length from successive observed `reset_at` values, falling back to 168h.
- [ ] **UIUX-06**: Relative countdown ("Resets in 5h 12m") when < 24h remains.
- [ ] **UIUX-07**: Cycle elapsed readout ("Day 3 of 7" / "42h of 168h").
- [ ] **NOTIF-01**: Threshold notifications (warning 85% / critical 95% used, deduped per window).
- [ ] **TREND-01**: 7-day local usage trend from opencode.db.

## Out of Scope

- WidgetKit Notification Center extension — menu bar app is the product surface
- Playwright dashboard scraping — fragile; PROJECT.md defers
- Pace-projection text ("in deficit / in reserve") — v2+; marker covers pace visually
- Display-mode toggle (remaining vs used) — ship one mode: remaining %
- Second-by-second ticking in the menu bar — redraw churn; render-time computation only

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| QUOTA-01 | (mapped in ROADMAP.md) | Not started |
| QUOTA-02 | (mapped in ROADMAP.md) | Not started |
| QUOTA-03 | (mapped in ROADMAP.md) | Not started |
| TIME-01 | (mapped in ROADMAP.md) | Not started |
| TIME-02 | (mapped in ROADMAP.md) | Not started |
| TIME-03 | (mapped in ROADMAP.md) | Not started |
| TIME-04 | (mapped in ROADMAP.md) | Not started |
| UIUX-01 | (mapped in ROADMAP.md) | Not started |
| UIUX-02 | (mapped in ROADMAP.md) | Not started |
| UIUX-03 | (mapped in ROADMAP.md) | Not started |
| UIUX-04 | (mapped in ROADMAP.md) | Not started |
| UIUX-05 | (mapped in ROADMAP.md) | Not started |
