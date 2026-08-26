<!-- GSD:project-start source:PROJECT.md -->

## Project

**OpenCode macOS Usage Widget**

A macOS menu bar app (SwiftUI, macOS 14+) that tracks LLM provider API usage at a glance. It shows DeepSeek balance, MiniMax balance/credit, and a ChatGPT Plus quota card with remaining percentage and next reset date. Data is fetched from provider balance endpoints and OpenCode's local database.

**Core Value:** Show the user their remaining AI budget and when it resets, at a glance from the menu bar — with zero interaction required.

### Constraints

- **Tech stack**: Swift 5.9+, SwiftUI, macOS 14+, Xcode 16+ — existing build system (XcodeGen)
- **Data**: OpenAI quota reset is a 168-hour (7-day) cycle per the user's model
- **Design**: B&W monochrome aesthetic already established
- **Compat**: Menu bar app only; no WidgetKit extension in current scope

<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->

## Technology Stack

## Executive Position

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift + SwiftUI + AppKit menu bar | Swift 5.9+ / macOS 14+ / Xcode 16+ | App shell, menu bar panel, B&W cards | Already the project's stack; this milestone adds no new language/framework. Keep. |
| `GET https://chatgpt.com/backend-api/wham/usage` | n/a (undocumented) | Read ChatGPT Plus/Codex quota: `used_percent` + `reset_at` per window | The **only** known endpoint that returns Plus quota *and* server-provided reset timestamps. Powers the official analytics page `chatgpt.com/codex/cloud/settings/analytics`. Verified independently in withLinda/CodexPlusBar (Swift), liamlai88/ai-usage-bar (Python), and this repo's prior `feature/openai-quota` branch. |
| OAuth token from `~/.codex/auth.json` | n/a | Auth for `wham/usage` | Codex CLI's own login token (`tokens.access_token`). Same pattern the app already uses for OpenCode's `auth.json` — read in-memory only, never persist/log. No Chrome cookie importing, no keychain prompts. The Python reference tool uses exactly this. |
| URLSession (async/await) + JSONDecoder | Foundation (macOS 14+) | Transport + decoding | Existing pattern in `DataFetcher.swift`; keep the `refreshAll()` shape. |
| Minute-granularity ticker for countdown + elapsed marker | SwiftUI (macOS 12+)/Observation | Drive "Resets at 3.08 pm", "in Xh Ym", and the moving elapsed-hours marker | Two proven options: `TimelineView(.everyMinute)` (display-only) or an `@Observable` async clock that `Task.sleep`s until the next minute boundary (used by CodexPlusBar's `AppMinuteClock`; testable, drives all views from one `now`). The elapsed marker only needs 1-minute resolution. |
| 15-minute polling `Timer` + reset-boundary refresh | Foundation | Keep coarse refresh; trigger an extra fetch shortly after the soonest `reset_at` | Already in `AppDelegate` (900s). Add: when `reset_at − now` falls inside the poll interval, schedule a one-shot fetch so the bar snaps back to 100% promptly. |

- `primary_window` = 5-hour rolling window; `secondary_window` = 7-day (168h) weekly cap. Both: `used_percent` (0–100) and `reset_at` (**unix seconds**).
- **Remaining % = `100 − used_percent`** (clamped 0–100).
- **Reset Date = `Date(timeIntervalSince1970: reset_at)`** — this is the "3.08 pm" the milestone wants; format locally (`Date.FormatStyle`/`DateFormatter`, e.g. `"Aug 15 at 3:08 PM"` or `"d MMM, h.mm a"` for the dot-format the user expects).
- **Elapsed hours since reset (168h cycle) = `168 − (resetAt − now) / 3600`** — anchor to `secondary_window.reset_at`; the marker position = `elapsed / 168` of bar width.
- Optional extras: `plan_type`, `credits.balance`, `rate_limit.limit_reached`.

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none new) | — | — | No third-party dependency is required for this feature. `TimelineView` and `Observation` are system frameworks. Resist adding an HTTP client or a JSON library — the existing `URLSession` + `JSONDecoder` pattern is sufficient and keeps the app dependency-free. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| XcodeGen + `xcodebuild` (existing) | Build system | Unchanged; add the new fetcher file to the `project.yml` sources list. |
| `codex login` (OpenAI Codex CLI) | Generate `~/.codex/auth.json` | The user must have signed in to Codex at least once for the token to exist. Document as a one-time setup step ("Sign in with Codex so that `~/.codex/auth.json` contains the OAuth session" — wording from the prior branch's README). |
| `curl` | Manual endpoint verification | `curl -s -H "Authorization: Bearer $(jq -r .tokens.access_token ~/.codex/auth.json)" https://chatgpt.com/backend-api/wham/usage` — use during the phase to confirm the schema before writing Swift. |

## Installation

# No new packages. Integration steps for the phase:

# 1. One-time: ensure the user has run `codex login` (creates ~/.codex/auth.json).

# 2. Add OpenAIQuotaFetcher.swift (or extend DataFetcher.swift) to opencode-widget/project.yml sources.

# 3. Extend OpenAIQuota model to carry BOTH windows (primary + secondary) instead of a single remainingPercent/resetDate.

# 4. Build:

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| OAuth token from `~/.codex/auth.json` | ChatGPT session cookies (CodexPlusBar imports them from Chrome into `WKWebsiteDataStore` + `ChatGPT-Account-ID` header) | Only when you need **multi-account** support (a pool of Plus accounts) or the user refuses to install the Codex CLI. Cost: heavy — launches Chrome, parses cookie DBs, needs Full Disk Access/keychain permissions. Overkill for a single-user widget. |
| `wham/usage` endpoint | Web scraping the ChatGPT UI (Playwright/Selenium) | Never, if `wham/usage` works — the endpoint returns clean JSON with the exact fields needed. Scraping is fragile, slower, and already out of scope per PROJECT.md. |
| Direct in-process URLSession polling | Node.js subprocess helper (`OpenAIQuotaHelper/index.mjs`) | Never — the prior branch **abandoned** the Node helper in favor of direct OAuth polling (commit d506519). Subprocess spawn + stdout parsing is fragile vs. an in-process `URLSession` call; don't resurrect v1. |
| `TimelineView(.everyMinute)` | `@Observable` async minute clock (AppMinuteClock pattern) | Prefer the async clock when the same `now` must drive several views/strings and you want unit tests; `TimelineView` is fine for a single display-only countdown. Either works on macOS 12+. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **OpenAI API platform usage endpoints** — `api.openai.com/v1/usage`, `api.openai.com/v1/organization/usage/{completions,embeddings,images,...}`, `GET /v1/organization/costs` | Documented (Admin > Usage in the API reference) but they return **token counts and dollar spend** for API platform billing, require an API key with Admin roles, and have zero relation to a ChatGPT Plus subscription. Plus does not include API quota (confirmed by OpenAI help-adjacent sources and the cline#8910 issue). They cannot produce a "99% remaining / resets Aug 15" card. | `chatgpt.com/backend-api/wham/usage` |
| **`api.openai.com/dashboard/billing/usage` and `/dashboard/billing/subscription`** | Legacy *undocumented* internal platform-billing endpoints (powered the old platform dashboard). API spend only, never Plus quota. Deprecation status unverified in this research (LOW confidence on timing) — regardless, they are the wrong tool. | `wham/usage` |
| **Playwright / headless-browser scraping** of chatgpt.com | Fragile DOM coupling, account-ban risk, heavy runtime; already deferred in PROJECT.md for MiniMax for the same reasons. | `wham/usage` JSON |
| **Chrome cookie importing** (CodexPlusBar approach) | Requires launching Chrome, decrypting cookie stores, Full Disk Access — disproportionate for one user's single account. | `~/.codex/auth.json` OAuth token |
| **Node.js helper subprocess** (prior v1) | Abandoned upstream in this very repo; process-spawn + parse is a fragile integration point for data a 10-line URLSession call retrieves. | In-process `URLSession` fetch |
| **`DispatchSourceTimer` / `BGTaskScheduler` / WidgetKit** for refresh | Menu bar apps run as regular foreground processes — a plain `Timer` or `Task.sleep` is correct and simplest. `BGTaskScheduler` is an iOS background mechanism; WidgetKit is out of scope per PROJECT.md. | AppDelegate `Timer` (existing) + reset-boundary one-shot |
| **Deriving reset time from local observation** (e.g., "I saw it reset last Tuesday, so next is +168h") | The server's `reset_at` is authoritative and already delivered; local derivation drifts and breaks on rate-card changes. | Trust `secondary_window.reset_at` |

## Stack Patterns by Variant

- Use `~/.codex/auth.json` → `tokens.access_token` with `Authorization: Bearer`.
- Because: matches the app's existing `auth.json`-reading pattern; zero new permissions.
- Prompt the user to run `codex login` (or `codex` once) in a Preferences note, and keep showing the last successfully cached quota (the prior branch's fallback to `previousQuota`).
- Because: the token is a ChatGPT OAuth session that expires; 401 means "re-auth", not "endpoint broken".
- Add the `ChatGPT-Account-ID` header (`tokens.account_id` or the workspace ID) and, if switching, the `/api/auth/session?exchange_workspace_token=true&workspace_id=...` flow from CodexPlusBar.
- Because: `wham/usage` scopes the response to the account identified by the header; without it the default account is used.
- Anchor to `secondary_window` only: `elapsedHours = 168 − max(0, (resetAt − now)/3600)`, marker x-position = `elapsedHours / 168` of bar width.
- Because: `secondary_window` IS the 7-day/168h window; mixing in the 5h primary window for the marker would make the marker jump mid-cycle.
- Format `secondary_window.resetAt` with the user's locale; the user's example "3.08 pm" implies 12-hour clock with dot separators (Malay locale) — use `Date.FormatStyle(date: .abbreviated, time: .shortened)` or an explicit `"d MMM 'at' h.mm a"` pattern, and refresh the string on the minute ticker.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `wham/usage` response (`used_percent`, `reset_at` as unix seconds) | Swift `Int`/`Double` + `Date(timeIntervalSince1970:)` | Both reference apps treat `reset_at` as seconds; no unit conversion needed. The prior branch decoded values as `Double` — `Int` is safer; be tolerant either way. |
| SwiftUI `TimelineView(.everyMinute)` | macOS 12+ | Project targets macOS 14+ — no availability gate needed. |
| `@Observable` minute clock | macOS 14+ | Same; matches project's Swift 5.9+ `@Observable` usage (`MenuBarState`). |
| Undocumented endpoint stability | n/a | **LOW confidence on persistence.** OpenAI renames backend endpoints without notice (the prior branch itself moved off a Node helper to direct calls; `wham/usage` is current as of Aug 2026 across 3 projects). Mitigate: graceful 401 handling, cached fallback, and keep the fetch isolated in one file so a future endpoint swap is a one-line change. Do NOT depend on response fields beyond `rate_limit.*.used_percent/reset_at`, `plan_type`. |

## Sources

- **withLinda/CodexPlusBar** (GitHub, Swift, updated 2026-08-07) — `Sources/Services/PlusProfileDataService.swift`, `WorkspaceLimitService.swift`, `AuthSessionService.swift`, `ChatGPTWebURLs.swift`, `AppMinuteClock.swift`, `WorkspaceModels.swift` — wham/usage endpoint, `ChatGPT-Account-ID` header, primary/secondary window decode, `remainingPercent = 100 − usedPercent`, reset countdown, minute-clock ticker. Confidence: HIGH (verified).
- **liamlai88/ai-usage-bar** (GitHub, Python, 2026-05) — `data_sources/codex_api.py` — same endpoint, Bearer auth from `~/.codex/auth.json` `tokens.access_token`, `Originator: codex_cli`/`User-Agent: codex_cli/0` headers, `credits.balance` + `limit_reached`. Confidence: HIGH (verified; second independent confirmation).
- **This repo's `feature/openai-quota` branch** (commits 667fefb, d506519) — prior implementation: `OpenAIQuotaFetcher.swift` (wham/usage + .codex/auth.json), `AuthReader.readOpenAICredentials` (`tokens.access_token` + `tokens.account_id`), prefers `secondary_window` for the weekly card. Confidence: HIGH (primary integration source).
- **developers.openai.com API reference — Administration > Usage** — documented endpoints are `/v1/organization/usage/*` and `/v1/organization/costs` (spend/tokens, Admin keys). Confidence: HIGH (official docs).
- **jdhodges.com — "How to Check Codex Usage in ChatGPT (2026)"** (2026-05-17) — analytics page at `chatgpt.com/codex/cloud/settings/analytics`, three meters (5-hour, weekly, credits), shared agentic usage limit, July 2026 Plus rate card. Confidence: MEDIUM (secondary source, consistent).
- **deepwiki.com/ndycode/oc-chatgpt-multi-auth — Rate Limits & Quotas** — reset timestamps are API-provided; plugin tracks `rateLimitResetTimes` per model family from server responses; countdown UI refreshes every 5s. Confidence: MEDIUM.
- **github.com/cline/cline#8910** (2026-01-28) — "ChatGPT Plus subscriptions have usage limits that reset in 5-hour windows and weekly caps... based on message quotas (not tokens)". Confidence: MEDIUM.
- **Apple Developer Documentation — TimelineView** (macOS 12+). Confidence: HIGH (stable, standard).

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
