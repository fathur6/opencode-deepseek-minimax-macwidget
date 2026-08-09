# Feature Research: LLM Usage / Quota-Reset Menu Bar Widget

**Domain:** macOS menu bar widget (SwiftUI) tracking LLM API balances and quota resets
**Researched:** 2026-08-09
**Confidence:** MEDIUM (cross-checked across multiple primary sources: CodexBar, TokenBar, minimax-usage-checker, onWatch, Apple docs, GitHub billing docs)

## Scope Note

This research focuses on the **ChatGPT Plus quota card** (remaining %, reset readout, elapsed-time bar with moving marker) — the active milestone — but surveys the whole LLM-usage-widget category since the same conventions apply to the DeepSeek/MiniMax cards.

---

## Reset-Countdown Conventions (What "Expected Behavior" Looks Like)

Direct answer to the milestone question — how quota-reset UI behaves in desktop widgets/dashboards today:

1. **Percent remaining is the primary number, not percent used.** CodexBar (19.8k★, the category reference): "Fill represents percent remaining by default" with an optional "Show usage as used" flip. minimax-usage-checker shows remaining prompts/%. GitHub Actions shows minutes remaining. → The existing "99% remaining" label is correct and expected.
2. **Both countdown forms exist and are table stakes together:** a relative countdown ("Resets in 3d 4h") and an absolute clock ("Reset Aug 15, 3:08 PM"). CodexBar ships both as layout tokens (`Resets in` / `Reset at`) and defaults the menu card to countdown with an optional absolute-clock display. Convention: **countdown by default, absolute as the persistent reset anchor.** For a 7-day cycle the absolute form ("Reset Aug 15, 3:08 pm") is the right primary readout; switch to a short relative form ("Resets in 5h 12m") when < 24h remains.
3. **Reset countdown is the category's core value.** CodexBar's headline: "Plan around resets. Per-provider session, weekly, and monthly windows with countdowns to the next reset — stop guessing whether to start that long task." The denshub (May 2026) category review frames the whole point: "You glance at the indicator and you see how much you have left. Then you decide whether to start that heavy task right now or wait twenty minutes."
4. **Elapsed-time-in-cycle is NOT a found convention.** No competitor renders a marker-on-bar for cycle position. The closest are: CodexBar's text pace labels ("X% in deficit / X% in reserve", "Runs out in…"), TokenBar's quota cards "with pace projections", and onWatch's quota-exhaustion forecast. **The elapsed-hours marker is a genuinely differentiating composition** — it is the visual equivalent of pace tracking (see Differentiators).
5. **Stale data must never blank a reading.** TokenBar: "A failed refresh never blanks a reading — the last known value stays until a fresh one lands." CodexBar dims the icon on failed refresh. → Persist last-known values; show staleness, don't show nothing.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Missing these = the widget feels broken/incomplete. Users give no credit for them but penalize absence.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Remaining % display | Dominant convention across the category (CodexBar %-remaining fill, minimax-checker, GitHub minutes); "99% remaining" already exists | LOW | Keep as the headline number. Do not switch to %-used as default. |
| Reset date AND time readout | "Reset Aug 15" exists; the category expects the time too (CodexBar `Reset at` absolute clock; minimax API exposes exact `endTime`/`remainsTime`). Active requirement. | MEDIUM | Must read an actual next-reset timestamp from the data source. Timezone = user's local; surface "3:08 PM" as PROJECT.md requires. |
| Auto-refresh + manual refresh | Every competitor has both (minimax 30s, CodexBar adaptive 5min default + fixed 1/2/5/15/30min, existing 15 min here) | LOW | 15 min is fine for balance %. Reset time + marker need NO network refresh — derivable from wall clock at render time. |
| Stale-data persistence | TokenBar/CodexBar both keep last-known values on failure; users trust the number only if it never vanishes | LOW–MEDIUM | Persist last-good snapshot; render a subtle "updated Xm ago" or dimmed state instead of blanks. |
| Click-to-open popover with Refresh + Quit | Already exists; universal menu-bar convention (Apple MenuBarExtra `.window` style) | LOW | Add Settings and "Open provider dashboard" as natural siblings. |
| Menu bar icon reflects status | Category standard: dynamic bar icon whose fill/color tracks quota (CodexBar two-bar meter, TokenBar signal bars/ring); B&W template icon needed for dark/light menu bar | MEDIUM | Existing B&W aesthetic is correct. Icon should visually hint remaining quota (fills up/down) and dim on stale/error. |
| Tooltip on menu bar icon | Standard macOS status-item behavior; hover = summary line | LOW | One-line summary: "ChatGPT Plus — 99% remaining — resets Aug 15, 3:08 PM". Cheap, high perceived polish. |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Elapsed-time marker on the usage bar** (active requirement) | The bar becomes dual-axis: fill = quota remaining, marker = where "now" is in the 168h cycle. At a glance you see **pace**: marker far right + bar nearly empty = healthy reserve; marker early + bar nearly full = deep deficit. No competitor renders this; it is a visual replacement for CodexBar's text pace labels. | MEDIUM | Marker position = f(now, resetTime, 168h). Compute from wall clock — no refresh needed, moves smoothly while popover is open. Handle marker≈fill collisions visually (offset/contrast). |
| Cycle elapsed readout ("Day 3 of 7" / "42h of 168h") | Complements the marker; makes cycle position explicit, not just inferred from marker position | LOW–MEDIUM | One small text element. CodexBar shows only time-to-reset, never time-into-cycle. |
| Threshold notifications (warning ~85% used / critical ~95% used, deduped per window) | minimax-usage-checker ships exactly this (warning 85% / critical 95%, "alerts sent once per model window to avoid spam"); CodexBar optional session-quota notifications; BurnRate/onWatch thresholds | MEDIUM | Needs refresh pipeline + `UserNotifications` permission + per-window dedup state. P2 — later, but proven demand. |
| Local-first usage history (opencode.db, 6-day window already aggregated) | 7-day sparkline/trend from local SQLite — same data strategy TokenBar uses ("reads local session logs"); no extra API surface | MEDIUM–HIGH | Differentiator for a future v2 chart; today's popover is too small. |

### Anti-Features (Seem Good, Create Problems)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Playwright / dashboard scraping (MiniMax web console) | "Complete" balance data without an API | Fragile: providers change internal endpoints/cookie formats and tools break for days (denshub explicitly warns; PROJECT.md already defers this). Heavy (browser automation), permission-hungry. | Use the balance APIs already integrated; if a provider lacks an endpoint, offer manual entry (already done for MiniMax) |
| Second-by-second ticking countdown in menu bar | "Live" feel | Menu-bar redraw churn + battery + visual noise; menu bar apps are passive by design | Compute countdown/marker from wall clock at render time; tick only while popover is open |
| Full charts / 3D contribution graphs in the popover (TokenBar's 3D graph, BurnRate 7-day charts) | Impressive, data-rich | Tiny popover real estate; destroys the at-a-glance B&W design that is this app's identity; drags in Charts complexity | Keep numeric at-a-glance; if history is ever needed, open a separate window (or WidgetKit later) |
| Aggressive "real-time" polling | Freshness | Providers rate-limit; CodexBar warns polling too often gets you rate-limited; WidgetKit clamps sub-5min refreshes anyway. 15 min already costs a rate window | Keep 15 min; consider adaptive refresh (only when popover open) much later |
| Auto-opening popover / proactive popups on refresh | Visibility | Hostile interruption; menu bar apps must be invisible until invoked | Notifications (opt-in, threshold-based) or icon state change |
| Persisting API keys in plaintext config | Convenience | Security anti-pattern (denshub: "The right answer is macOS Keychain"); project correctly reads OpenCode's auth.json in-memory only | Keep in-memory-only reading of `~/.local/share/opencode/auth.json`; never write keys to app config |
| "Remaining vs used" display-mode toggle | Customization parity with CodexBar | Configuration clutter in a 3-card minimal widget; user specified remaining-% design | Ship one mode: remaining % (per design); revisit only if users ask |

---

## Feature Dependencies

```
[Reset date+time readout (from data source)]
    └──requires──> [accurate next-reset timestamp parsed from provider data]

[Elapsed-time marker on bar]
    └──requires──> [Reset date+time readout]  (marker = f(now, resetTime, 168h))

[Relative countdown "Resets in 3d 4h"]
    └──requires──> [Reset date+time readout]

[Cycle elapsed readout "Day 3 of 7"]
    └──requires──> [Reset date+time readout] + [168h cycle length]

[Usage bar fill]
    └──requires──> [remaining %]  (existing)

[Stale-data persistence] ──enhances──> [all readouts]

[Threshold notifications]
    └──requires──> [auto-refresh pipeline] + [stale snapshot store] + UserNotifications permission

[Local history chart] ──enhances──> [opencode.db aggregation]  (already exists)
```

### Dependency Notes

- **Marker requires the reset timestamp, not the other way around.** The active requirement to read reset date AND time is the critical path — everything else in this milestone hangs off it.
- **Cycle length must be derived, not hard-coded.** The marker math uses "168h − rounded remaining hours" per the user's model, but the *reset time* comes from the data source. If the observed reset interval ever differs from 168h (provider changes semantics), the marker and countdown silently drift. Derive cycle length from (last reset → next reset) where possible; fall back to 168h.
- **Wall-clock derivability is the architectural win:** marker position, countdown, and cycle-elapsed need zero network refresh — they are pure functions of `now` + reset time. Only the % bar needs the 15-min pipeline.
- **Stale-value store enhances everything:** one persisted snapshot (values + timestamps) serves the icon, the tooltip, and the popover — and is the prerequisite for threshold notifications later.

---

## MVP Definition

### Launch With (this milestone)

The active milestone is already well-scoped; these are the features that complete the ChatGPT Plus card:

- [x] Remaining % label (existing)
- [x] "Reset Aug 15" date (existing)
- [ ] Reset date AND time readout (e.g. "3:08 PM") — **critical path; everything below depends on it**
- [ ] Usage bar below the % label, above the reset row; fill proportional to usage (e.g. ~1% glows at 99% remaining)
- [ ] Moving vertical marker on the bar = elapsed hours since reset (168h − rounded remaining hours)
- [ ] Marker + countdown computed from wall clock at render time (no extra refresh)
- [ ] Icon tooltip summarizing the card (cheap polish, high perceived quality)

### Add After Validation (v1.x)

- [ ] Stale-value persistence (keep last-known on failed refresh; dim icon) — reliability trust
- [ ] "Open provider dashboard" menu action (and Settings alongside existing Refresh/Quit)
- [ ] Relative countdown form ("Resets in 5h 12m") when < 24h to reset; absolute otherwise
- [ ] Cycle elapsed readout ("Day 3 of 7") — tiny add, reinforces the marker concept

### Future Consideration (v2+)

- [ ] Threshold notifications (85%/95% used, deduped per window) — proven demand, needs permission flow
- [ ] Pace projection text ("at this rate you'll run out in X / lasts until reset") — CodexBar/onWatch feature; the marker already gives visual pace
- [ ] 7-day usage trend from opencode.db — separate window or WidgetKit, not the popover
- [ ] Adaptive refresh (refresh-on-open) — after usage patterns are proven

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Reset date+time readout | HIGH | LOW | P1 |
| Usage bar (fill = usage %) | HIGH | LOW | P1 |
| Elapsed-time marker on bar | HIGH | MEDIUM | P1 |
| Wall-clock countdown/marker math | HIGH | LOW | P1 |
| Icon tooltip | MEDIUM | LOW | P2 |
| Stale-value persistence | HIGH | LOW–MED | P2 |
| Relative countdown form (<24h) | MEDIUM | LOW | P2 |
| Cycle elapsed readout ("Day 3 of 7") | MEDIUM | LOW–MED | P2 |
| Open provider dashboard action | MEDIUM | LOW | P2 |
| Threshold notifications | MEDIUM | MEDIUM | P3 |
| Pace projection text | MEDIUM | MEDIUM | P3 |
| 7-day history chart | LOW–MED | HIGH | P3 |
| WidgetKit extension | LOW | HIGH | P3 (out of scope per PROJECT.md) |

**Priority key:**
- P1: Must have for this milestone
- P2: Should have, add when possible
- P3: Nice to have / future consideration

---

## Competitor Feature Analysis

| Feature | CodexBar (19.8k★, ref impl) | TokenBar (248★) | minimax-usage-checker (this project's inspiration) | onWatch (Go daemon) | Our Approach |
|---------|------------------------------|-----------------|---------------------------------------------------|---------------------|--------------|
| Remaining % display | ✓ %-remaining fill (default) | ✓ quota-left in title | ✓ remaining prompts/% | ✓ | ✓ existing |
| Reset date/time | ✓ `Resets in` countdown + `Reset at` absolute tokens | ✓ quota cards | ✓ `endTime`/`remainsTime` from API | ✓ reset tracking + anomaly detect | ✓ date (exists) + time (this milestone) |
| Elapsed-in-cycle marker | ✗ (text pace labels only) | ✗ (pace projection cards) | ✗ (linear progress bars only) | ✗ (forecast text) | ✓ **marker on bar — unique** |
| Usage bar | ✓ menu card bars | ✓ signal bars / ring / popsicle | ✓ color-coded linear bars | ✓ web dashboard bars | ✓ this milestone |
| Refresh | adaptive 5min default; 1/2/5/15/30 fixed | on-demand + periodic | 30s fixed | 60s fixed | 15 min (existing) |
| Stale-data resilience | ✓ dims icon on failure | ✓ keeps last value | — | ✓ SQLite snapshots | pending (P2) |
| Notifications | optional quota alerts | — | ✓ 85%/95% thresholds, deduped | ✓ email/push thresholds | pending (P3) |
| Data source | cookies/OAuth/API keys/local files | local session logs (SQLite/JSONL) | MiniMax API | provider APIs + local | provider balance APIs + opencode.db |

**Category takeaways for us:**
- CodexBar validates every feature we already have or plan (reset readout, % remaining, refresh, icon status). It proves demand, not novelty — except the marker.
- TokenBar validates the local-SQLite data strategy (reads local session logs) — our opencode.db aggregation is a legitimate, privacy-positive approach.
- minimax-usage-checker (the direct inspiration) validates the notification thresholds and window-based (`startTime`/`endTime`/`remainsTime`) mental model — the same start/end/remaining triad our marker needs.

---

## Sources

| Source | Type | What It Gave Us | Confidence |
|--------|------|-----------------|------------|
| CodexBar README + docs/ui.md + docs/widgets.md (github.com/steipete/CodexBar, 19.8k★, fetched 2026-08-09) | Primary (ref implementation) | Reset countdowns as core value; `Resets in`/`Reset at`/`Runs out` tokens; %-remaining fill; pace deficit/reserve; adaptive refresh; stale dimming; widget snapshot pipeline | HIGH (primary + corroborated) |
| TokenBar README (github.com/Nanako0129/TokenBar, 248★) | Primary (competitor) | Stale-value persistence; quota cards w/ pace projections; icon styles; local-log data strategy | MEDIUM (single source, corroborates CodexBar patterns) |
| minimax-usage-checker README (github.com/AungMyoKyaw/minimax-usage-checker — project's inspiration) | Primary (inspiration) | 85%/95% threshold alerts w/ dedup; `startTime`/`endTime`/`remainsTime` window model; 30s refresh; color-coded bars | MEDIUM (single source) |
| denshub.com/en/ai-token-usage-monitors-macos (May 2026 category review) | Secondary (market survey) | Category positioning ("glance and decide"); tool-by-tool comparison; Keychain vs plaintext keys; scraping fragility warning | MEDIUM (dated, single reviewer) |
| GitHub Actions billing docs (docs.github.com) | Primary (adjacent domain: metered quota) | Billing-cycle reset semantics; 90%/100% alert thresholds; quota-block behavior | HIGH (official docs) |
| Apple MenuBarExtra docs (developer.apple.com) | Primary (platform) | LSUIElement; menu-bar-only app auto-termination; `.window` popover style; `isInserted` binding; template icons | HIGH (official docs) |
| OpenRouter docs (openrouter.ai/docs) | Primary (adjacent: credit-based usage) | Credits/balance exposure via MCP server; credit-based tracking as category norm | MEDIUM (fetch limited) |

**Confidence rationale:** Core conventions (remaining %, reset countdown, refresh, stale persistence, icon status) are corroborated by 3+ independent primary sources → HIGH. The marker-on-bar differentiation claim is an inference from absence (no competitor implements it) → MEDIUM, flag for validation against user acceptance. Vendor counts/star numbers are as-fetched on 2026-08-09 and will drift.

**Known gaps:** No direct source documents the exact visual form of the elapsed marker (the composition is novel); the 168h cycle model is user-specified, not provider-documented — verify against observed reset timestamps during implementation. ChatGPT Plus quota endpoints are undocumented/console-internal; reset semantics should be read from the actual reported value, not assumed.

---
*Feature research for: OpenCode macOS Usage Widget — ChatGPT Plus quota card milestone*
*Researched: 2026-08-09*
