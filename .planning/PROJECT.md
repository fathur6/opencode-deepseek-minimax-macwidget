# OpenCode macOS Usage Widget

## What This Is

A macOS menu bar app (SwiftUI, macOS 14+) that tracks LLM provider API usage at a glance. It shows DeepSeek balance, MiniMax balance/credit, and a ChatGPT Plus quota card with remaining percentage and next reset date. Data is fetched from provider balance endpoints and OpenCode's local database.

## Core Value

Show the user their remaining AI budget and when it resets, at a glance from the menu bar — with zero interaction required.

## Requirements

### Validated

- ✓ DeepSeek balance via `GET https://api.deepseek.com/user/balance` — existing
- ✓ MiniMax credit via `GET https://platform.minimax.io/account/query_balance` — existing
- ✓ MiniMax prompt usage via `/v1/api/openplatform/coding_plan/remains` — existing
- ✓ Manual MiniMax credit entry with save/cancel — existing
- ✓ 15-minute auto-refresh — existing
- ✓ B&W monochrome design — existing
- ✓ ChatGPT Plus quota card showing remaining % and reset date — existing

### Active

- [ ] Widget reads the OpenAI (ChatGPT Plus) next refresh date AND time (e.g. 3.08 pm)
- [ ] Usage bar positioned below the "99% remaining" label, above the "Reset Aug 15" row
- [ ] Bar fills proportional to usage (e.g. ~1% glows when 1% used / 99% remaining)
- [ ] Moving vertical marker on the bar showing elapsed hours since reset (168h cycle − rounded remaining hours)
- [ ] Mechanism + UI/UX planned for the widget's OpenAI reset timeline

### Out of Scope

- Playwright-based MiniMax dashboard scraping — deferred (README future enhancement)
- Additional providers (Anthropic, Google) — future enhancement
- Notification Center WidgetKit extension — the app is a menu bar app today

## Context

- Original inspiration: minimax-usage-checker by AungMyoKyaw; Lobe Icons for brand icons.
- API keys read from OpenCode's auth config at `~/.local/share/opencode/auth.json` (in-memory only).
- Usage history aggregated from `~/.local/share/opencode/opencode.db` (SQLite, `session` table, 6-day window).
- Build: `cd opencode-widget && xcodegen generate && xcodebuild -scheme OpencodeWidgetApp -configuration Debug build`.
- ChatGPT Plus quota card already shows "99% remaining" and "Reset Aug 15" — this phase adds the reset-time reading and the animated usage bar.
- Linear project "OpenCode macOS Usage Widget" exists (Backlog) but has no active issues yet.

## Constraints

- **Tech stack**: Swift 5.9+, SwiftUI, macOS 14+, Xcode 16+ — existing build system (XcodeGen)
- **Data**: OpenAI quota reset is a 168-hour (7-day) cycle per the user's model
- **Design**: B&W monochrome aesthetic already established
- **Compat**: Menu bar app only; no WidgetKit extension in current scope

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Usage bar below % label, above reset row | User-specified position | — Pending |
| Bar shows usage progress; vertical marker = hours elapsed since reset | User-specified composition (168h − rounded remaining hours) | — Pending |

---
*Last updated: 2026-08-09 after initialization*
