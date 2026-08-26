# Pitfalls Research

**Domain:** macOS menu bar LLM usage widget (SwiftUI) — ChatGPT Plus quota card with 168-hour reset timeline, usage bar, and elapsed-time marker
**Researched:** 2026-08-09
**Confidence:** HIGH for Calendar/DST math and menu bar lifecycle (Apple docs + WWDC); HIGH for endpoint shape (verified across 3 independent implementations per STACK.md); MEDIUM for rounding/marker-drift UX and undocumented-API stability

## Critical Pitfalls

### Pitfall 1: Treating "168 hours" as calendar arithmetic instead of a duration anchored to a server timestamp

**What goes wrong:**
The milestone's model is "168h cycle − rounded remaining hours" for the elapsed marker. If the code computes the *next reset* as `lastReset + TimeInterval(604800)` (adding seconds) or reconstructs the cycle from local observation, the reset time drifts across Daylight Saving Time transitions: a week of elapsed time is **not** 604,800 seconds when a DST shift falls inside it (23 or 25-hour days). The widget's "Reset Aug 15, 3:08 pm" then disagrees with what ChatGPT actually resets, and the elapsed marker is off by an hour for half the year.

**Why it happens:**
- Mixing two time models: `TimeInterval` arithmetic (`Date + 604800`) is absolute-elapsed-time; `Calendar.date(byAdding:)` is calendar-aware (DST-safe). The two only agree when no transition occurs in the window.
- WWDC21 "What's new in Foundation" states it directly: *"For calculations that are in terms of hours, days, etc., please use Calendar API."*
- The project's constraint says "168-hour (7-day) cycle per the user's model" — a *duration* model, but the actual data source (per STACK.md, `chatgpt.com/backend-api/wham/usage`) returns an **absolute `reset_at` unix timestamp** for the 7-day `secondary_window`. The server timestamp is authoritative; 168h is only useful for converting that timestamp into "elapsed hours" display math.

**How to avoid:**
- Never derive the next reset locally. Persist the server's `reset_at` (unix seconds → `Date`) and treat it as ground truth; the 168h constant is used only in display math: `elapsed = 168 − (resetAt − now)/3600`.
- If you ever must compute a future reset from a past one (offline fallback), use `Calendar.current.date(byAdding: .day, value: 7, to:)`, never `+ 604800` (Swift Foundation has no DST-aware TimeInterval addition).
- Use `Calendar.autoupdatingCurrent` (not `Calendar.current`, which caches the timezone) if timezone changes while the app runs — e.g., user travels; and format `reset_at` with the *current* timezone explicitly at render time.

**Warning signs:**
- Reset hour shown is wrong by exactly 1h around DST spring/fall weekends (hard to spot — only manifests 2 weeks/year).
- Unit tests that assert elapsed hours using a fixed `+ 604800` constant pass but disagree with the real clock in March/November.
- Marker and the ChatGPT app's own reset clock disagree by an hour.

**Phase to address:**
- Phase: reset-timestamp ingestion & time model (the "read reset date AND time" requirement). Verify with unit tests pinned to a known DST transition date (e.g., 2026-11-01 US fall-back inside a 7-day window) asserting the marker math stays anchored to the server `reset_at`, and that no code path computes reset from `TimeInterval(604800)`.

---

### Pitfall 2: Rounding "remaining hours" before computing elapsed, and letting rounding clamp drift the marker

**What goes wrong:**
The spec formula is literally "168h − rounded remaining hours". If implemented as `elapsed = 168 − Int((resetAt − now)/3600)` (truncating) or with `rounded()`, the marker:
- **Jumps backward**: at an hour boundary, remaining goes 12.4 → 12.0 → 11.6, and rounding can make elapsed tick 156 → 156 → 157 then back — visible as a jittering marker.
- **Saturates early**: when remaining < 0.5h, `rounded` gives 0 → elapsed = 168 → marker pinned at the far right while the countdown label still says "in 30 min", then snaps back after reset. Looks like a bug.
- **Goes out of range**: remaining 168.4h (clock skew / server ahead) → elapsed negative; remaining negative (marker past reset) → elapsed > 168, marker off the bar.

**Why it happens:**
Rounding the *intermediate* value instead of the *display* value. The single round in the user's formula is a display simplification; implementing it as a data transformation injects ±1h error into the marker position and creates discontinuity at every hour boundary.

**How to avoid:**
- Compute continuously: `let elapsed = (now.timeIntervalSince(resetAt) / 3600) + 168` (or `168 − remainingSeconds/3600`) as a `Double`; **round only in the view layer** (`Int(elapsed.rounded())` or format directly).
- Clamp: `elapsed = min(max(elapsed, 0), 168)`; marker position = `elapsed/168` clamped to 0...1 before mapping to bar width.
- Derive countdown label and marker from the **same `now` snapshot** in a single render pass (see Pitfall 5), so they can never disagree by a tick.

**Warning signs:**
- Marker jumps backwards at hour boundaries when observed across a minute tick.
- Marker touches the right edge while the countdown still reads "in Xm".
- Negative elapsed / >168 elapsed in debug output or console logs.

**Phase to address:**
- Phase: marker/elapsed computation. Add unit tests: remaining 0.4h → marker at 100% but *not* before reset passes; remaining 12.6h → elapsed 155.4 (not 156); clock ahead of reset → clamped 0; clock past reset → clamped 168.

---

### Pitfall 3: Marker (time-in-cycle) and bar fill (quota-used) are different axes — presenting them as one "status" without documenting the mismatch

**What goes wrong:**
The bar fill = `used_percent` from the server (quota consumed). The marker = elapsed time in the 168h cycle. These measure different things and only coincide when usage is perfectly linear. When the user burns quota in bursts (agentic coding sessions), the fill edge and the marker drift apart — marker at 30% of the bar, fill at 80% — and the user reads the gap as "something is wrong." The feature's actual value (per FEATURES.md this is the *pace* differentiator: marker early + fill high = deep deficit) is lost if the UI doesn't label the two semantics.

**Why it happens:**
Two numeric sources (server usage % and wall clock) visualized on one shared bar with no legend. The milestone's composition ("bar fills proportional to usage", "marker = elapsed hours") is correct but unlabeled; without a caption ("filled = used, tick = time into cycle") the dual-axis reading is ambiguous, and any mismatch reads as a bug.

**How to avoid:**
- Give the bar an explicit dual-axis affordance: label the fill ("used") and the marker ("time in cycle"), or add a tiny "Day 3 of 7" / "42h of 168h" caption (FEATURES.md recommends this).
- When marker and fill collide (both near the same x), offset the marker slightly or stroke it so it stays visible (ties into Pitfall 8).
- Do not "correct" one to match the other — that destroys the pace signal. Document in a tooltip/caption that the marker is time-based, not usage-based.

**Warning signs:**
- In review, someone "fixes" the marker to align with the fill edge, silently deleting the differentiator.
- Testers report "the bar is wrong" when they use the widget during a burst of heavy usage.
- No visual distinction between fill and marker in dark mode (see Pitfall 8).

**Phase to address:**
- Phase: bar + marker UI. Verify with a screenshot set at two synthetic states: (fill 10%, marker 70%) and (fill 90%, marker 20%) — both must read as *intended pace* states, not rendering errors.

---

### Pitfall 4: Undocumented endpoint reliability — silent failure reads as "99% remaining forever"

**What goes wrong:**
`GET https://chatgpt.com/backend-api/wham/usage` is undocumented, requires the Codex CLI OAuth token, and can change response shape without notice (STACK.md rates endpoint persistence LOW). Current `DataFetcher.swift` uses `JSONSerialization` with string-coercion (`as? String` then `Double()`), which returns `nil` on any format change. A nil quota decodes into "99% remaining" (or the last cached value) with no error surfaced — the widget shows a confident, wrong number indefinitely, and the marker/countdown keep counting down to a reset time that may be stale.

**Why it happens:**
- Failure is swallowed at every layer: `try?` + optional coercion + optional chaining → the UI can't distinguish "fetch failed" from "quota is 99%".
- The existing 15-minute refresh keeps overwriting the cache with the same nil-derived value, so staleness is invisible.
- The endpoint is auth-sensitive: expired/rotated Codex token, missing `User-Agent`/`Originator` headers, or multi-account (`ChatGPT-Account-ID`) mismatches all yield 401/403 — which the current code silently treats as "no data".

**How to avoid:**
- Decode with typed `Codable` structs (per STACK.md schema) and keep **both** windows (`primary_window` 5h, `secondary_window` 7d); the prior branch dropped one window — a schema change or wrong window selection then silently shows the wrong %.
- Propagate fetch state: `enum FetchState { case loading, loaded(WidgetCache), failed(String), stale(Date) }` — UI shows `--`, a dim "stale" treatment, or an error row; never fabricate a healthy-looking percentage from nil.
- Persist `reset_at` and the fetch timestamp; if refresh fails, surface `lastUpdated` age (the widget already stores `lastUpdated` — display it when stale).
- Isolate the endpoint URL, required headers, and token source (`~/.codex/auth.json`, in-memory only, same pattern as OpenCode's `auth.json`) in one file so a 403 → token-refresh fix is a one-line change.

**Warning signs:**
- Console/log shows 401/403 or JSON decode failures but the menu card still shows "99%".
- `lastUpdated` is hours old but the UI looks fresh.
- After a Codex CLI update, the card freezes at the last value.

**Phase to address:**
- Phase: OpenAI quota fetch & decode. Verification: kill the network / revoke the token and confirm the card visibly degrades (stale indicator), then restore and confirm recovery; add a debug log line for every decode failure.

---

### Pitfall 5: Menu bar lifecycle — timers throttled (App Nap), tickers drift, and countdowns derived from tick counts go stale across sleep

**What goes wrong:**
A menu bar app has no visible window, so it is a prime App Nap candidate: the system **reduces the frequency with which timers fire** (Apple Energy Efficiency Guide, "Extend App Nap"). Any countdown implemented as "subtract 1 per timer tick" (or `Timer.publish` accumulated state) drifts behind the wall clock: after screen sleep, App Nap throttling, or the menu being open (tracking run loop mode), the marker and "Resets in Xh Ym" readouts lag reality. A minute-ticker that fires late compounds the error every tick.

**Why it happens:**
- Timers are not a time source — they are *events* that may be delayed; `Timer` in `.default` mode doesn't even fire while a menu is tracking.
- Energy guide: "If your app uses timers, consider whether you truly need them" and set tolerance ≥10% of interval; a ticking display timer is exactly the anti-pattern it warns about.
- Menu bar apps also have a hard lifecycle edge: per Apple's MenuBarExtra docs, *"An app that only shows in the menu bar will be automatically terminated if the user removes the extra from the menu bar."* The countdown state must survive relaunch (persisted `reset_at`), not live in a ticking in-memory timer.

**How to avoid:**
- **Never accumulate time; always read `Date.now` at render.** Marker/countdown are pure functions `f(now, resetAt)` (FEATURES.md: "wall-clock derivability is the architectural win"). Use `TimelineView(.everyMinute)` for the popover (display-only, correct after sleep) or an `@Observable` clock that `Task.sleep`s to the next minute boundary (CodexPlusBar's pattern, per STACK.md) — both recompute from `now`, never from tick counts.
- Keep the coarse 15-min `Timer` for *network* refresh only (fine to be throttled); set `timer.tolerance = 90` (10%).
- On launch, restore `reset_at` from `DataStore` and compute immediately — do not wait for the first tick.
- For the icon/countdown to update while the menu is open, drive it from the SwiftUI view's clock, not the AppDelegate timer.

**Warning signs:**
- After sleep/wake, marker position and "Resets in" jump to catch up with the wall clock.
- Energy Impact gauge in Xcode shows high wakeups (timer firing every minute even when the popover is closed).
- Countdown is correct in the debugger but wrong on the user's machine after overnight sleep.

**Phase to address:**
- Phase: lifecycle/clock architecture (minute ticker + render-time computation). Verify: sleep the Mac mid-cycle, wake, confirm countdown is exact; open the menu and watch the marker advance smoothly without a separate menu-mode timer.

---

### Pitfall 6: Choosing the wrong quota window (5h primary vs 7d secondary) and labeling the card ambiguously

**What goes wrong:**
The endpoint returns **two** windows: `primary_window` (5-hour rolling) and `secondary_window` (7-day/168h weekly cap) — each with its own `used_percent` and `reset_at`. The milestone's "99% remaining / 168h cycle" maps to `secondary_window`. If the code decodes only one window (the prior branch's bug per STACK.md) or picks the wrong one, the card shows e.g. the 5-hour number with a 7-day reset time — internally inconsistent, and it will never match what the ChatGPT app itself displays for that window. A user comparing the widget to chatgpt.com sees a contradiction and stops trusting the widget.

**Why it happens:**
- The endpoint is undocumented; the response has no self-describing labels beyond window names — easy to index `rate_limit.primary_window` when the intent was `secondary_window`.
- "Quota" is ambiguous in ChatGPT Plus (multiple limits per account); the 168h assumption in PROJECT.md pins it to the weekly cap, which must be explicit in code.

**How to avoid:**
- Decode both windows into named fields (`primary`/`secondary`), pick `secondary` for the 168h card, and *assert* the choice in a comment + test ("the card displays the 7-day window per project model").
- Label the card text ("7-day cap") so the window is identifiable even if the UI later adds the 5h readout.
- If the observed interval between successive `reset_at` values for `secondary_window` ever ≠ 168h (provider changes semantics), derive cycle length from `(lastReset → nextReset)` and fall back to 168h (FEATURES.md dependency note) — never silently assume.

**Warning signs:**
- Widget % doesn't match chatgpt.com analytics for the same window.
- `reset_at` values look like they're ~5h apart but the card claims a 7-day cycle.
- Any code path referencing `rate_limit` without a window qualifier.

**Phase to address:**
- Phase: quota decode & window selection. Verify: fixture with both windows present and distinct values → card shows the 7-day value and labels it; fixture with only one window → graceful degrade, not a crash or wrong-window read.

---

### Pitfall 7: Monochrome B&W legibility — 1–2px marker and fill become indistinguishable in dark menu bar / dark mode

**What goes wrong:**
The established B&W aesthetic renders with `.primary`/`.secondary`/opacity levels. A 1–2px vertical marker drawn in the same black/gray as the bar fill disappears when the bar is ≥50% filled (marker overlaps fill), and in dark mode a `.black` marker on a near-black track vanishes. The "~1% glows" effect the milestone wants ("~1% glows when 1% used") has no color channel to glow with — if implemented with a color it breaks the monochrome contract; if implemented with opacity it's invisible at 1%.

**Why it happens:**
- Color is the default differentiation mechanism; removing it removes the marker/fill/background separation that designers rely on, and nothing replaces it with a luminance/pattern strategy.
- Menu bar template icons (`isTemplate = true`) auto-adapt to light/dark; the current icon code sets `img.isTemplate` *conditionally* (`deepseekBalance != nil || minimaxBalance != nil`), so a nil-balance state renders a **color** PNG in the dark menu bar → black-on-black icon.

**How to avoid:**
- Differentiate by **pattern/structure**, not just gray level: give the marker a contrasting treatment (hollow ring, cross-hatch, or a 2px bar in inverted luminance — e.g., white stroke on dark fill in dark mode via `.environment(\.colorScheme)`); give the fill a texture or distinct opacity tier (25%/50%/75% usage thresholds get stepped fill styles).
- For the "glow at 1%", use a brightening/whitening of the fill edge or an animated pulse in the same hue family — luminance-based, not color.
- Make `isTemplate` unconditional for the menu bar icon (or supply proper template variants) so it always adapts to the menu bar's light/dark state.
- Test both `colorScheme` values and both menu bar appearances; check contrast at 1px width on a Retina display.

**Warning signs:**
- Screenshot in dark mode shows the marker only where the bar is empty.
- The menu bar icon is invisible in dark menu bar when balances are nil.
- A reviewer proposes adding a color accent "just for the marker" — the monochrome contract silently erodes.

**Phase to address:**
- Phase: bar + marker UI (and a small icon-template fix in the same phase). Verification: dark-mode and light-mode screenshots at fill 0%, 50%, 100% with marker at 25%/75%; 1% fill must be visible.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hard-code `168` hours and compute reset from `Date()` observation | No server timestamp needed | Drifts with DST; breaks if provider changes cycle; card contradicts ChatGPT | Never — server `reset_at` exists; use it |
| Reuse `JSONSerialization` string-coercion for the new endpoint (existing pattern in `DataFetcher.swift`) | Consistency with current code | Silent nil on schema change → "99% forever" (Pitfall 4) | Never for the quota card; migrate to `Codable` |
| Single minute-ticker `Timer` driving both refresh and countdown | One mechanism | App Nap/sleep drift + battery wakeups (Pitfall 5) | Only if it recomputes from `Date.now` every tick and has tolerance |
| Decode only `secondary_window` | Less code | Wrong-window read when response shape changes; no 5h context (Pitfall 6) | MVP-only if a comment marks it; extend in v1.x |
| Marker drawn as a 1px gray line matching the fill | Minimal code | Invisible at overlap/dark mode (Pitfall 7) | Only with a luminance-contrast treatment |
| Store `reset_at` as a formatted local string ("Aug 15, 3:08 PM") in the cache | Trivial to display | Timezone/DST bugs on re-display; can't recompute marker (Pitfall 1) | Never — store `Date`/unix seconds, format at render |
| Ignore the 5h `primary_window` entirely | Focus on the 168h card | Users comparing to ChatGPT's 5h indicator see mismatch | Acceptable for this milestone if labeled "7-day" |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `chatgpt.com/backend-api/wham/usage` | Sending only `Authorization: Bearer`; missing `User-Agent`/`Originator` headers → 403 | Mirror the working reference recipe exactly (STACK.md): `Bearer` token, `Accept: application/json`, optional `ChatGPT-Account-ID`, codex-cli user-agent/originator |
| Codex OAuth token (`~/.codex/auth.json`) | Caching/`try?`-ing a rotated token; persisting it to disk | Read in-memory each refresh (existing `AuthReader` pattern); on 401, surface "re-login with codex" rather than showing stale quota |
| `reset_at` unix seconds | Formatting with a fixed timezone or a stale `Calendar.current` | `Date(timeIntervalSince1970:)` + current timezone at render; use `autoupdatingCurrent` |
| Multi-account setups | Omitting `ChatGPT-Account-ID` when the token maps to several accounts | Send the account ID if present (STACK.md), matching the analytics page the user expects |
| OpenCode DB (`session` table) | Reusing its 6-day usage for the 7-day card | It's unrelated data — don't cross-derive the reset from local session history |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Per-second (or `.everySecond`) ticking countdown | High wakeups in Energy gauge; battery drain | Compute from `Date.now`; tick at most per-minute, and only while the popover is open | 1–2 wakeups/sec — visible on laptop battery immediately |
| Accumulating elapsed time from timer ticks (`elapsed += 1`) | Marker/countdown lag after sleep/App Nap | Recompute `elapsed` from `reset_at` and `now` every render | After any sleep > a few minutes; grows unbounded |
| Fetching quota every minute "to catch resets" | 60x more API calls than needed; token/rate pressure on an undocumented endpoint | Keep 15-min refresh; schedule a one-shot fetch shortly after the soonest `reset_at` (STACK.md) | Only matters at scale, but the endpoint is unofficial — don't hammer it |
| Heavy decode on the main actor each tick | Popover stutters when opened | Decode once per refresh off-main; views only read computed values | Not yet a problem at this scale — but keep the ticker path allocation-free |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Persisting the Codex OAuth token (`~/.codex/auth.json` content) to the widget's own storage | Token theft from the shared container | In-memory only (existing pattern); never write to `DataStore`/UserDefaults |
| Logging the Authorization header or token on 401/403 | Token leak in Console | Log status codes and error kinds, never header values |
| Shipping `auth.json` path with no existence guard | Crash/`try?`-nil cascade on fresh installs | Guard file existence; show "Sign in with Codex CLI" state instead of `--` |
| Reading `~/.codex/auth.json` with world-readable perms | Other local processes read the token | Verify file permissions (600) match OpenCode's auth handling; warn if 644 |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| "99% remaining" with no window label | User compares against ChatGPT's 5h number and distrusts the widget | Label "7-day cap" on the card (Pitfall 6) |
| Marker and fill unlabeled on one bar | The gap reads as a bug, not pace info | Caption/tooltip: "filled = used, tick = time into cycle" (Pitfall 3) |
| Countdown jumps backward at hour boundaries | Looks like a live bug | Round only at display; clamp (Pitfall 2) |
| Silent `--` on fetch failure, no staleness cue | User assumes it's a real zero/nil | Show `lastUpdated` age or dim the card when stale (Pitfall 4) |
| Reset time shown in a fixed format regardless of locale | "3.08 pm" dot-format expectation conflicts with some locales | Use `Date.FormatStyle` with explicit `.hour(.twoDigits(amPM: .abbreviated)).minute()` and test the dot separator per locale |
| Marker hidden under the fill at overlap | Marker disappears exactly when most informative (late in cycle) | Luminance-inverted stroke or offset (Pitfall 7) |

## "Looks Done But Isn't" Checklist

- [ ] **Reset timestamp:** Often the card stores the *formatted string* ("Aug 15, 3:08 PM") instead of the `Date` — verify the cache holds unix seconds/`Date` and formatting happens at render.
- [ ] **Marker math:** Often the "168h − rounded remaining" formula is applied as data transformation (truncation/clamping bugs) — verify it's Double math + display-only rounding + clamping 0...168.
- [ ] **Both windows decoded:** Often only `primary_window` (or only `secondary`) is decoded — verify the fixture with both windows and that the card explicitly selects `secondary`.
- [ ] **Dark mode:** Often the B&W design is validated only in light mode — verify marker/fill/icon at both `colorScheme` values and both menu bar appearances.
- [ ] **Sleep/wake:** Often countdown correctness is tested interactively, not after sleep — verify the marker/countdown are exact immediately after wake (render-time `Date.now`).
- [ ] **Failure state:** Often nil quota renders as a healthy-looking card — verify a blocked fetch visibly degrades (stale/dim/error) instead of showing the last good %.
- [ ] **Timer tolerance/invalidation:** Often the 15-min timer keeps firing after the app loses its status item — verify the timer is invalidated/owned by the app delegate lifecycle.
- [ ] **DST window:** Often unit tests use fixed offsets — verify a test pinned to a DST transition weekend (e.g., 2026-11-01) keeps the marker anchored to `reset_at`.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| 168h treated as calendar arithmetic (Pitfall 1) | MEDIUM — logic change, not UI | Replace `+604800` with `reset_at` persistence; keep calendar-based fallback; re-run DST tests |
| Rounding/clamp drift (Pitfall 2) | LOW | Move rounding to the view; add clamps; update unit tests |
| Dual-axis confusion (Pitfall 3) | LOW | Add caption/tooltip; no logic change |
| Silent failure (Pitfall 4) | MEDIUM | Add `FetchState`; surface `lastUpdated`; switch decode to `Codable` |
| Ticker drift across sleep (Pitfall 5) | MEDIUM | Replace accumulation with render-time `Date.now`; add tolerance |
| Wrong window (Pitfall 6) | LOW | Fix selection + label; verify against chatgpt.com |
| B&W legibility (Pitfall 7) | LOW–MEDIUM | Luminance treatments for marker/fill; fix `isTemplate` |
| Token rotation 401s | LOW | Read token fresh each refresh; surface "re-login" state |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Calendar/DST vs duration (Pitfall 1) | Reset-timestamp ingestion & time model | DST-pinned unit test; no `+604800` in codebase |
| Rounding/clamp drift (Pitfall 2) | Marker/elapsed computation | Unit tests at 0.4h/12.6h/negative/>168 remaining |
| Dual-axis mismatch (Pitfall 3) | Bar + marker UI | Synthetic screenshots at contrasting fill/marker states |
| Silent endpoint failure (Pitfall 4) | OpenAI quota fetch & decode | Kill network/token → card visibly degrades; `Codable` decode |
| Timer/App Nap/sleep drift (Pitfall 5) | Lifecycle/clock architecture | Sleep-wake test; Energy gauge wakeups; render-time `Date.now` |
| Window selection (Pitfall 6) | Quota decode & window selection | Two-window fixture; card labels "7-day" |
| B&W legibility (Pitfall 7) | Bar + marker UI | Dark/light screenshots; marker visible at fill overlap and 1% |

## Sources

- Apple Developer, "Calendar" API reference — `autoupdatingCurrent`, `date(byAdding:)`, `RepeatedTimePolicy` (DST) — https://developer.apple.com/documentation/foundation/calendar (HIGH)
- WWDC21 session 10109, "What's new in Foundation" — *"For calculations that are in terms of hours, days, etc., please use Calendar API"* — https://developer.apple.com/videos/play/wwdc2021/10109/ (HIGH)
- Apple Energy Efficiency Guide for Mac Apps — "Extend App Nap" (timer throttling for invisible apps) and "Minimize Timer Usage" (tolerance, invalidation) — https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/ (HIGH)
- Apple Developer, "MenuBarExtra" — *"An app that only shows in the menu bar will be automatically terminated if the user removes the extra from the menu bar"* — https://developer.apple.com/documentation/swiftui/menubarextra (HIGH)
- STACK.md (this project's parallel research, 2026-08-09) — `wham/usage` endpoint, both-window schema, auth recipe, ticker patterns (HIGH for shape, MEDIUM/LOW for endpoint stability)
- FEATURES.md (this project's parallel research, 2026-08-09) — reset-countdown conventions, dual-axis marker framing, wall-clock derivability (HIGH)
- Community tracker oc-chatgpt-multi-auth (DeepWiki, indexed 2026-03-07) — server-provided `rateLimitResetTimes`, per-family windows — https://deepwiki.com/ndycode/oc-chatgpt-multi-auth/4.4-rate-limits-and-quotas (MEDIUM)
- cline/cline issue #8910 (2026-01-28) — "usage limit reached" with ChatGPT Plus; 5-hour + weekly caps — https://github.com/cline/cline/issues/8910 (MEDIUM)
- aifreeapi.com post (2025-12-30) — ChatGPT Plus reset mechanisms (3h rolling / daily UTC / weekly), model-picker reset display — https://www.aifreeapi.com/en/posts/chatgpt-plus-usage-quota-reset-time (MEDIUM)

---
*Pitfalls research for: OpenCode macOS Usage Widget — ChatGPT Plus quota-reset timeline milestone*
*Researched: 2026-08-09*
