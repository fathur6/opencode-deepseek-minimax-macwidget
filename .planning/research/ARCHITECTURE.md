# Architecture Research: OpenAI/ChatGPT Plus Reset-Timeline Feature

**Domain:** macOS menu bar usage widget (SwiftUI, macOS 14+) — OpenAI/ChatGPT Plus quota card with 168h reset timeline
**Researched:** 2026-08-09
**Confidence:** HIGH for code-layout findings (read from source + git history); MEDIUM for external endpoint semantics (cross-checked web sources, undocumented API)

> **Headline finding:** The "existing" ChatGPT Plus card from `.planning/PROJECT.md` **does not exist on `main`**. It exists only on the remote branch `feature/openai-quota` (2 commits: `667fefb feat: monitor OpenAI subscription quota`, `d506519 Use OAuth polling for ChatGPT quota`). The current milestone's quota-timeline work must first port/merge that branch — the reset-timeline bar is an *extension* of that card, not a modification of something already shipped.

---

## Standard Architecture

### System Overview

The repo is a **two-app, three-source-tree** project compiled by two independent build systems. This is the single most important architectural fact:

```
┌─────────────────────────────────────────────────────────────────────┐
│  Sources/OpencodeWidgetApp        (menu bar app — THIS FEATURE LIVES HERE)│
│  ┌─────────────┐ ┌────────────────┐ ┌──────────────────────────┐     │
│  │ AppDelegate │→│ DataFetcher    │→│ OpenAIQuotaFetcher (new) │     │
│  │ (Timer 900s)│ │ (refreshAll)   │ │ GET /backend-api/wham/   │     │
│  └──────┬──────┘ └───────┬────────┘ │ usage (OAuth Bearer)     │     │
│         │                │          └──────────────────────────┘     │
│  ┌──────┴────────────────┴─────────┐                                  │
│  │ MenuBarState (@Observable)      │  ← in-memory cache of the view │
│  │  deepseek, minimax, openAIQuota │                                  │
│  └──────────────┬──────────────────┘                                  │
│  ┌──────────────┴──────────────────┐                                  │
│  │ MenuContent (NSHostingView menu)│  ← ChatGPT Plus card renders here│
│  │   ├─ QuotaResetBar (new,        │     (below the two balance cards)│
│  │   │  TimelineView-driven marker)│                                  │
│  │   └─ "99% remaining" / "Resets  │                                  │
│  │      Aug 15, 3:08 PM" labels    │                                  │
│  └─────────────────────────────────┘                                  │
├─────────────────────────────────────────────────────────────────────┤
│  Sources/OpencodeWidgetShared     (Foundation-only library layer)    │
│  ┌──────────┐ ┌───────────┐ ┌───────────────┐                        │
│  │ Models   │ │ DataStore │ │ AuthReader    │                        │
│  │ (Widget- │ │ (JSON     │ │ (opencode +   │                        │
│  │  Cache,  │ │  cache)   │ │  codex OAuth) │                        │
│  │  OpenAIQuota)          │ │               │                        │
│  └──────────┘ └───────────┘ └───────────────┘                        │
├─────────────────────────────────────────────────────────────────────┤
│  Sources/OpencodeUsageTrackerApp  (SEPARATE windowed app — NOT in the│
│  menu bar XcodeGen target)        Dashboard/Usage/History tabs,      │
│  ProgressBar · StatCard · TimelineChart · DesignSystem               │
│  Its components are NOT available to the menu bar app today.         │
└─────────────────────────────────────────────────────────────────────┘
```

**Target topology (verified in `project.yml` + `Package.swift`):**

| Build system | Targets | What it builds |
|---|---|---|
| XcodeGen (`project.yml`) | `OpencodeWidgetApp` (1 app target, sources = `OpencodeWidgetApp/` + `OpencodeWidgetShared/`) | The shipped menu bar app. This is the documented build path. |
| SwiftPM (`Package.swift`) | `OpencodeWidgetShared` (lib) + `OpencodeWidgetApp` (exec) + `OpencodeUsageTrackerApp` (exec) | Same app via SPM, plus the separate windowed tracker app. |

**Consequence:** `ProgressBar.swift`, `StatCard.swift`, `TimelineChart.swift`, `DesignSystem` in `Sources/OpencodeUsageTrackerApp/` are **not compiled into the menu bar app**. They are reachable only via the SwiftPM tracker executable. Reusing them would require either adding tracker sources to the XcodeGen target (dragging in `DesignSystem`/`UsageStatus` dependencies) or promoting them into `OpencodeWidgetShared` (coupling the shared layer to SwiftUI — currently it is SwiftUI-free). Neither is worth it for a ~40-line bar.

### Component Responsibilities

| Component | Responsibility | Location | Communicates With |
|---|---|---|---|
| `AppDelegate` | Owns status item, 900s refresh `Timer`, wires cache → state → menu | `OpencodeWidgetApp/OpencodeWidgetApp.swift` | `DataFetcher`, `DataStore`, `MenuBarState` |
| `MenuBarState` | `@Observable` in-memory view state (`openAIQuota`, balances, `lastUpdated`) | same file | `MenuContent` (reads) |
| `DataFetcher.refreshAll()` | Orchestrates parallel provider fetches, returns `WidgetCache`; falls back to cached OpenAI quota (stale-while-revalidate) | `OpencodeWidgetApp/DataFetcher.swift` | `OpenAIQuotaFetcher`, `AuthReader`, `DataStore` |
| `OpenAIQuotaFetcher` | GET `https://chatgpt.com/backend-api/wham/usage`; decodes `rate_limit.secondary_window` (weekly) → `primary_window` (5h); validates `used_percent` ∈ [0,100]; returns `OpenAIQuota(remainingPercent: 100 − used_percent, resetDate: reset_at)` | `OpencodeWidgetApp/OpenAIQuotaFetcher.swift` (branch) | `AuthReader.readOpenAICredentials`, `URLSession` |
| `OpenAIQuota` + `WidgetCache.openAIQuota` | Shared data model: `remainingPercent: Double?`, `resetDate: Date?`; part of persisted cache | `OpencodeWidgetShared/Models.swift` (branch) | `DataStore` (encode/decode), all consumers |
| `AuthReader.readOpenAICredentials` | Reads `~/.codex/auth.json` → `tokens.access_token` + optional `tokens.account_id`; never logs/persists the token | `OpencodeWidgetShared/AuthReader.swift` (branch) | `OpenAIQuotaFetcher` |
| `MenuContent` | SwiftUI menu body; renders the OpenAI card (labels + bar + reset row); static `quotaText`/`resetText` helpers | `OpencodeWidgetApp/OpencodeWidgetApp.swift` | `MenuBarState` |
| `QuotaResetBar` (**new**) | Timeline bar: filled portion = used %, vertical marker = elapsed hours in the 168h cycle; `TimelineView(.periodic(by: 60))` recomputes marker from `context.date` | `OpencodeWidgetApp/Components/QuotaResetBar.swift` (**new**) | `OpenAIQuota` (via injected values), no timer plumbing |
| `QuotaResetTimeline` (**new**) | Pure time-derivation math: `cycleHours = 168`, `cycleStart = resetDate − 168h`, `elapsedHours(at:)`, `remainingHours(at:)`, `elapsedFraction(at:)` (clamped) | `OpencodeWidgetShared/Models.swift` (**extend**) | testable in `OpencodeWidgetSharedTests` |

---

## Recommended Project Structure (delta for this milestone)

```
opencode-widget/Sources/
├── OpencodeWidgetApp/
│   ├── OpencodeWidgetApp.swift        # MenuContent: insert QuotaResetBar between % label and reset row
│   ├── DataFetcher.swift              # already wired for openAIQuota on branch
│   ├── OpenAIQuotaFetcher.swift       # already exists on feature/openai-quota
│   ├── PreferencesView.swift          # untouched (branch removes it from menu; keep unless desired)
│   └── Components/
│       └── QuotaResetBar.swift        # NEW — self-contained bar + TimelineView marker
├── OpencodeWidgetShared/
│   ├── Models.swift                   # OpenAIQuota exists on branch; ADD QuotaResetTimeline computed props
│   ├── DataStore.swift                # untouched — OpenAIQuota already Codable in WidgetCache
│   └── AuthReader.swift               # readOpenAICredentials exists on branch
└── OpencodeUsageTrackerApp/           # UNTOUCHED — do not import its components into the widget
```

### Structure Rationale

- **Keep the bar in `OpencodeWidgetApp`**: `project.yml` globs the whole `Sources/OpencodeWidgetApp` folder, so a new `Components/` subfolder is picked up automatically by `xcodegen generate` — no `project.yml` edit needed for a new file.
- **Keep derivation math in `OpencodeWidgetShared`**: `QuotaResetTimeline` must be pure (no SwiftUI), testable via `OpencodeWidgetSharedTests`, and usable by any future consumer (e.g., the tracker app or a WidgetKit extension later). The shared layer stays SwiftUI-free — this is an invariant to preserve.
- **Do not touch `OpencodeUsageTrackerApp`**: its `ProgressBar`/`DesignSystem` look similar but live in a different executable; sharing them now is a target-coupling refactor with no user value.

---

## Architectural Patterns

### Pattern 1: Pure time-derivation model (`QuotaResetTimeline`)

**What:** The elapsed-marker is a pure function of `(resetDate, now)` — no state, no timers. Encapsulate in a value type with injected `now` so it is unit-testable and deterministic.

```swift
public struct QuotaResetTimeline: Equatable {
    public let resetDate: Date
    /// Weekly window from the API (limit_window_seconds = 604800) == 168h.
    public static let cycleHours: TimeInterval = 168
    public static let cycleDuration: TimeInterval = 3600 * cycleHours

    public var cycleStart: Date { resetDate.addingTimeInterval(-Self.cycleDuration) }

    public func elapsedHours(at now: Date = Date()) -> Double {
        max(0, now.timeIntervalSince(cycleStart) / 3600)
    }
    /// Per spec: marker = 168h − *rounded* remaining hours.
    public func remainingHours(at now: Date = Date()) -> Double {
        max(0, Self.cycleHours - elapsedHours(at: now).rounded())
    }
    /// 0.0 = just reset, 1.0 = next reset. Clamped for clock skew / server drift.
    public func elapsedFraction(at now: Date = Date()) -> Double {
        min(1, max(0, elapsedHours(at: now) / Self.cycleHours))
    }
}
```

**When to use:** any time-derived visual in a view (marker position, "Xh elapsed" caption).
**Trade-offs:** pure + testable; requires callers to pass `now` (the view injects `TimelineView`'s `context.date`). Overkill for one-off formatting; exactly right here because the marker must not tick on the data-refresh loop.

### Pattern 2: `TimelineView(.periodic)` for clock-like UI (the marker updater)

**What:** The 900s refresh loop refreshes *network data* only. The marker is a pure function of the wall clock, so it is driven by SwiftUI's `TimelineView`, which re-evaluates its body from `context.date` on a schedule — no `Timer` in `AppDelegate`, no mutation of `MenuBarState`.

```swift
struct QuotaResetBar: View {
    let remainingPercent: Double   // 0–100 remaining
    let resetDate: Date?

    var body: some View {
        if let resetDate {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let timeline = QuotaResetTimeline(resetDate: resetDate)
                let usedFraction = min(1, max(0, (100 - remainingPercent) / 100))
                let elapsedFraction = timeline.elapsedFraction(at: context.date)
                BarGeometry(usedFraction: usedFraction, markerFraction: elapsedFraction)
            }
        }
    }
}
// BarGeometry: GeometryReader; fill width = geo.width * usedFraction;
// marker x = geo.width * markerFraction (thin 1pt vertical line, primary color)
```

**When to use:** moving markers, countdown labels, any view that must change purely with time.
**Trade-offs:** idiomatic, zero plumbing, and the menu-hosted `NSHostingView` naturally pauses ticking when the menu closes (run-loop scheduled). Alternative `Timer.publish` + `.onReceive` couples timer lifecycle to view identity — not needed here. Marker updates once per minute; a 168h cycle moves ~0.1%/min, so 60s granularity is invisible.

### Pattern 3: Stale-while-revalidate for the quota value

**What:** When `OpenAIQuotaFetcher.fetch` fails (401 expired token, network down, endpoint drift), `DataFetcher.refreshAll()` keeps the **previous cached** quota from `DataStore` (`previousQuota ?? fetched`), so the card and marker never blank out. This is already implemented on `feature/openai-quota` — preserve it.

**When to use:** any fragile/undocumented fetch whose failure should degrade gracefully.
**Trade-offs:** shows stale percent until a successful refresh; correct behavior for a glance widget. Optionally annotate staleness ("last updated Xm ago") later — not required now.

---

## Data Flow

### Fetch / state flow (direction: network → cache → memory → view)

```
Timer (900s) / manual Refresh
    ↓
DataFetcher.refreshAll()          ── parallel: DeepSeek, MiniMax, OpenAI
    ├── OpenAIQuotaFetcher.fetch  → AuthReader(~/.codex/auth.json) → GET wham/usage → OpenAIQuota
    │        (failure → DataStore.load().openAIQuota as fallback)
    ↓
WidgetCache (incl. openAIQuota)   ── Codable, ISO8601 dates
    ├── DataStore.save()          → app-group JSON file (disk, survives relaunch)
    ↓
MenuBarState.openAIQuota          (in-memory @Observable)
    ↓
MenuContent → QuotaResetBar       TimelineView ticks: marker = f(resetDate, context.date) — NO network
```

### Key Data Flows

1. **Quota value flow:** `wham/usage` → `OpenAIQuotaFetcher` (validates `used_percent`, computes `remainingPercent = 100 − used`, `resetDate = reset_at`) → `DataFetcher` merges into `WidgetCache` → `DataStore` (disk) + `MenuBarState` (memory) → `MenuContent` labels. Direction is strictly one-way; views never write back.
2. **Marker flow:** `resetDate` (from flow 1) + wall clock (`TimelineView`'s `context.date`) → `QuotaResetTimeline.elapsedFraction` → marker x-position. This flow has **no dependency on the 900s timer** and never touches `DataStore`.
3. **Persistence flow:** `WidgetCache` is the single serializable snapshot; `openAIQuota` rides along with existing `DataStore` codec — no schema migration needed beyond the optional field (Codable default handles old cache files).

---

## Build Order (dependencies between components)

1. **Port `feature/openai-quota` to `main`** (or fold its two commits into this phase's first plan) — provides `OpenAIQuota`, `OpenAIAuthCredentials`/`readOpenAICredentials`, `OpenAIQuotaFetcher`, `MenuContent` card, `DataFetcher` wiring, `MenuContentTests`, `OpenAIQuotaFetcherTests`. *Everything else depends on this.*
   - Addresses: data model, fetch, auth, card placement.
   - Avoids: pitfall "building the bar on a card that doesn't exist on main".
2. **Extend shared model with `QuotaResetTimeline`** + tests in `OpencodeWidgetSharedTests` (fixed `Date` fixtures: 0h → fraction 0, 84h → 0.5, 168h+ → 1.0 clamp; rounding of remaining hours). No dependencies beyond step 1.
3. **Build `QuotaResetBar` component** (`Sources/OpencodeWidgetApp/Components/QuotaResetBar.swift`) — TimelineView + GeometryReader marker; takes `remainingPercent` + `resetDate` as plain inputs. Depends on 2.
4. **Wire into `MenuContent`** — insert bar between the "% remaining" label and the "Resets …" row; extend `resetText` to include time (`date.formatted(.dateTime.month(.abbreviated).day().hour().minute())`, local timezone) to satisfy "read next refresh date AND time (e.g. 3.08 pm)"; update/extend `MenuContentTests`. Depends on 2+3.
5. **`xcodegen generate` + `xcodebuild`** — verify the new `Components/` subfolder compiles (it will, via folder glob) and the branch's `LSUIElement`/activation-policy change (pure menu bar, no dock icon) is intentional.

**Phase ordering rationale:** data model first (shared, testable, no UI), then the bar, then the card wiring — each step compiles independently and is verifiable; the risky external dependency (wham endpoint) is isolated in step 1's fetcher with tests and the stale fallback.

---

## Scaling Considerations

Single-user local app; "scale" here means degradation over time, not users.

| Concern | Today (1 user) | After 1 year | Mitigation |
|---|---|---|---|
| OAuth token expiry | 401 → stale fallback shows old % | Same | Surface stale state; remind to `codex login`; the fetcher already returns nil on 401 |
| Endpoint drift (undocumented API) | Fields `used_percent`/`reset_at` per current shape | May change | Keep decoding strict + optional; prefer raw field names over labels; treat as graceful-degradation, not crash |
| Clock skew / non-fixed resets | Marker clamped 0...1 | Same | Clamp in `elapsedFraction`; the 168h constant is the *user's model* — the API's weekly window is `limit_window_seconds = 604800` exactly, so drift is minimal |
| Refresh frequency | 15 min | Same | Do NOT raise; marker is clock-driven, not network-driven |

**First bottleneck:** token expiry (401). **Second:** API shape changes. Neither blocks the milestone; both are already handled by the nil-fallback path.

---

## Anti-Patterns

### Anti-Pattern 1: Computing the marker in the 900s refresh loop
**What people do:** store `elapsedHours` in `MenuBarState`, recompute on every `refreshAll()`.
**Why it's wrong:** the marker would jump in 15-minute steps and drift; the menu would show a wrong position for up to 15 min; you conflate network cadence with clock cadence.
**Do this instead:** derive the marker in the view from `TimelineView`'s `context.date` (Pattern 2). The state layer stores only `resetDate`.

### Anti-Pattern 2: Importing tracker-app components into the menu bar target
**What people do:** `#if canImport` or add `Sources/OpencodeUsageTrackerApp/Components` + `DesignSystem` to `project.yml` to reuse `ProgressBar`.
**Why it's wrong:** two build systems, target coupling, shared layer gains a SwiftUI dependency; the tracker's `ProgressBar` is also color-coded (green/orange/red) — wrong for the B&W monochrome design.
**Do this instead:** a ~40-line self-contained `QuotaResetBar` in the app target, styled like the existing cards (`Color.primary.opacity(0.06)` background, `.cornerRadius(6)`).

### Anti-Pattern 3: Hardcoding "168" only in the view
**What people do:** `168 * 3600` inline in the bar, or worse `7 * 24` in two places.
**Why it's wrong:** the cycle constant must be the single source of truth, unit-tested, and shared with any future countdown label.
**Do this instead:** `QuotaResetTimeline.cycleHours` in the shared layer (Pattern 1).

### Anti-Pattern 4: Treating `wham/usage` as a stable API
**What people do:** assuming `used_percent`/`reset_at` will never change; crashing or blanking the card when the shape shifts.
**Why it's wrong:** it's an undocumented internal endpoint (401/403/field drift all observed in the wild).
**Do this instead:** optional decoding, nil-tolerant validation (already on the branch), stale fallback, and a README note that re-login may be needed.

---

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---|---|---|
| `https://chatgpt.com/backend-api/wham/usage` | GET, `Authorization: Bearer <access_token>`, optional `ChatGPT-Account-ID: <account_id>`, `Accept: application/json` | Undocumented internal endpoint; prefers `rate_limit.secondary_window` (weekly, `limit_window_seconds`=604800 = 168h) over `primary_window` (≈5h, 18000s); fields `used_percent` (0–100), `reset_at` (unix seconds). 401 = expired token, 403 = not authorized. Token source: `~/.codex/auth.json` → `tokens.access_token` (+ `tokens.account_id`). |
| `~/.codex/auth.json` | Read-only, in-memory only | Never log/persist; the OAuth session is owned by Codex. |
| `~/.local/share/opencode/opencode.db` | SQLite via `sqlite3` | Unrelated to this feature (usage history); unchanged. |
| App-group container (`group.com.opencode.widget` + `widget-data.json`) | `DataStore` JSON | `OpenAIQuota` rides `WidgetCache`; optional field keeps old cache files decodable. |

### Internal Boundaries

| Boundary | Communication | Notes |
|---|---|---|
| `DataFetcher` ↔ `OpenAIQuotaFetcher` | Direct async call, injected `URLSession` + `authPath` + `endpoint` (testability) | Fetcher is `enum` static; keep dependency injection via parameters (already on branch) |
| `MenuBarState` ↔ `MenuContent` | `@Observable` singleton read-only from views | Views must not mutate state |
| `QuotaResetBar` ↔ `MenuContent` | Plain value parameters (`remainingPercent`, `resetDate`) | Bar stays dumb; no `MenuBarState` reference inside |
| `QuotaResetTimeline` ↔ `QuotaResetBar` | Pure struct method call with injected `now` | Keeps math in shared, unit-testable |

---

## Sources

- **Code (HIGH):** `project.yml`, `Package.swift`, `Sources/OpencodeWidgetApp/*`, `Sources/OpencodeWidgetShared/*`, `Sources/OpencodeUsageTrackerApp/*` (read directly, main branch)
- **Code (HIGH):** `git show origin/feature/openai-quota:...` — `OpenAIQuotaFetcher.swift`, `OpencodeWidgetApp.swift`, `Models.swift`, `AuthReader.swift`, `DataFetcher.swift`, `MenuContentTests.swift`, `OpenAIQuotaFetcherTests.swift`, branch README
- **Web (MEDIUM, cross-checked):** knightli.com "Codex Usage Limits Explained: 5-Hour Reset, Weekly Quota, and Credits" (2026-04-15) — confirms dual windows (5h `18000s` + weekly `604800s` = 168h), raw fields `used_percent`/`percent_left`/`reset_at`/`limit_window_seconds`, 401/403 semantics, endpoint is internal and unstable
- **Web (MEDIUM):** openai/codex issue #10869 — confirms Codex TUI polls the same rate-limit endpoint
- **Web (MEDIUM):** DeepWiki AntiHub "Codex Accounts" page (DDG snippet) — "dual-window rate limiting… 5-hour and weekly time windows. Each window maintains its own `used_percent` (0-100) and `reset_at` timestamp"
- **Web (MEDIUM):** third-party implementations confirming the polling pattern: `codex-quota`, `tokenuse.app` docs, `pi-chatgpt-limit` package
- **Docs (MEDIUM, curated):** SwiftUI `TimelineView(.periodic(from:by:))` — clock-driven body re-evaluation from `context.date`; GeometryReader marker positioning

**Confidence notes:** Target layout, data flow, and build order are HIGH (verified against source and git). The wham endpoint shape and the 168h weekly equivalence are MEDIUM — they match the branch implementation, multiple independent third-party tools, and community write-ups, but the endpoint is undocumented and may drift. The 5h primary window is *not* used by this feature (weekly secondary window preferred — already the branch behavior).

---
*Architecture research for: OpenAI/ChatGPT Plus reset-timeline feature in the OpenCode macOS usage widget*
*Researched: 2026-08-09*
