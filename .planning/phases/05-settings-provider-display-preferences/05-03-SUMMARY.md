---
phase: 05-settings-provider-display-preferences
plan: 03
subsystem: provider-refresh
tags: [swift, macos, urlsession, keychain, provider-credentials, regression-tests]
requires:
  - phase: 05-02
    provides: Keychain-first per-provider credential resolver
provides:
  - Independent DeepSeek and MiniMax credential resolution for refresh collection
  - Presentation-isolation regression coverage for requests, cache, usage, and chart inputs
affects: [05-04, provider-refresh, provider-settings, cache, ledger, charts]
tech-stack:
  added: []
  patterns: [optional injected resolver seam, per-provider async credential resolution, presentation-only collection regression fixtures]
key-files:
  created: []
  modified:
    - opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift
    - opencode-widget/Tests/OpencodeWidgetAppTests/DataFetcherTests.swift
decisions:
  - "Use an optional ProviderCredentialResolver injection seam while constructing the Keychain-first resolver from the existing auth path in production."
  - "Resolve DeepSeek and MiniMax once each before issuing only their selected endpoint calls; do not route card visibility into refresh."
metrics:
  duration: 4min
  completed: 2026-09-17
  tasks_completed: 2
  files_modified: 2
status: complete
---

# Phase 05 Plan 03: Independent Provider Refresh Summary

**Refresh collection now resolves DeepSeek and MiniMax independently through the Keychain-first boundary while visibility remains strictly a rendering concern.**

## Accomplishments

- Added red/green regression coverage for DeepSeek-only and MiniMax-only credentials, selected endpoint requests, OpenAI fetch continuation, usage rows, and cached quota behavior.
- Added an injectable `ProviderCredentialResolver` seam to `refreshAll`; production still uses the Keychain-first resolver with the existing legacy-auth path fallback.
- Preserved the existing OpenAI stale-while-revalidate merge, MiniMax credit/usage fallback, cache fields, daily ledger-ready usage, and empty chart-history handoff.
- Exercised every combination of persisted card-visibility values and asserted identical requests plus cache, ledger-ready, and chart-input fields.

## Task Commits

1. **Task 1: Specify independent refresh and display-isolation regression behavior** — `a8c5c15` (`test`)
2. **Task 2: Resolve and fetch each provider without changing data semantics** — `d9cd91f` (`feat`)

## Decisions Made

- Kept the resolver optional at the `refreshAll` boundary so production creates the Keychain-first resolver using its supplied legacy-auth path, while tests inject an in-memory credential store without touching the host Keychain.
- Resolved each provider once and guarded only its own existing HTTPS calls; no display-preference type, argument, branch, or persistence path was introduced in collection.
- Retained the no-MiniMax-credential cached-credit timestamp behavior from the prior fallback branch.

## Verification

- RED: `swift test --scratch-path /tmp/opencode-widget-phase05-03 --filter DataFetcherTests` failed as intended because `refreshAll` did not yet expose the resolver seam.
- GREEN: `swift test --scratch-path /tmp/opencode-widget-phase05-03 --filter DataFetcherTests` passed — 25 `DataFetcherTests` with 0 failures.
- `git diff --check` passed before both task commits.
- Static audit found no `ProviderDisplayPreferences`, `isCardVisible`, or `setCardVisible` reference in `DataFetcher.swift`; no new logging or persistence path carries credentials.
- The focused build retained one pre-existing unrelated warning in `Sources/OpencodeWidgetLedger/QuotaLedger.swift` about an unused `withCString` result.

## TDD Gate Compliance

- RED commit `a8c5c15` precedes GREEN commit `d9cd91f` in git history.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None - modified production paths use resolved credentials and existing provider/cache data rather than placeholder values.

## Self-Check: PASSED

- Required `DataFetcher.swift` and `DataFetcherTests.swift` files exist.
- Task commits `a8c5c15` and `d9cd91f` exist in repository history.

---
*Phase: 05-settings-provider-display-preferences*
*Completed: 2026-09-17*
