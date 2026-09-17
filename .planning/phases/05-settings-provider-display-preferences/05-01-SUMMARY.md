---
phase: 05-settings-provider-display-preferences
plan: 01
subsystem: presentation-preferences
tags: [swift, foundation, userdefaults, xctest, provider-cards]
requires: []
provides:
  - Typed, independent provider-card visibility persistence with default-visible recovery.
  - Pure fixed-order provider-card selection that supports charts-only rendering.
affects: [05-02, 05-03, 05-04, 05-05, MenuContent, ProviderSettingsView]
tech-stack:
  added: []
  patterns: [injectable UserDefaults facade, per-provider non-secret keys, pure presentation layout]
key-files:
  created:
    - opencode-widget/Sources/OpencodeWidgetShared/ProviderDisplayPreferences.swift
    - opencode-widget/Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift
  modified: []
key-decisions:
  - "Use explicit namespaced UserDefaults keys per provider, with malformed and missing values recovering to visible."
  - "Keep card selection a pure ProviderID order filter with no cache, credential, ledger, chart, or network dependency."
patterns-established:
  - "Presentation preferences use injectable UserDefaults and object(forKey:) as? Bool ?? true."
  - "Provider-card order derives exclusively from ProviderID.allCases."
requirements-completed: [SETTINGS-02, SETTINGS-03]
coverage:
  - id: D1
    description: "Independent, default-visible per-provider display preferences"
    requirement: SETTINGS-02
    verification:
      - kind: unit
        ref: "opencode-widget/Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift#ProviderDisplayPreferencesTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Fixed visible-card order and empty charts-only card layout"
    requirement: SETTINGS-03
    verification:
      - kind: unit
        ref: "opencode-widget/Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift#testVisibleCardsFilterEveryCombinationInFixedProviderOrder"
        status: pass
    human_judgment: false
duration: 2 min
completed: 2026-09-17
status: complete
---

# Phase 05 Plan 01: Provider Display Preferences Summary

**Typed per-provider UserDefaults visibility preferences and a pure fixed-order card layout, with default-visible recovery and charts-only support.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-09-17T15:11:48Z
- **Completed:** 2026-09-17T15:14:09Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Specified isolated XCTest coverage for missing, malformed, legacy, independent, idempotent, and final-write-wins visibility behavior.
- Added `ProviderID` in fixed DeepSeek, MiniMax, OpenAI order with explicit non-secret presentation preference keys.
- Added a pure `ProviderCardLayout` filter that returns the enabled sequence or an empty charts-only layout without touching collection or storage paths.

## Verification

- `cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-01 --filter ProviderDisplayPreferencesTests` — passed (5 tests, 0 failures).
- The focused suite failed at RED only because `ProviderID`, `ProviderDisplayPreferences`, and `ProviderCardLayout` did not yet exist; it passed after the production implementation.
- Static boundary check confirmed the new preferences source has no `DataStore`, `WidgetCache`, credential, auth, network, ledger, or quota dependency.

## Task Commits

1. **Task 1: Specify provider visibility and compact-layout behavior** — `6e1a1a4` (`test`)
2. **Task 2: Implement typed display preferences and pure card layout** — `dfdc216` (`feat`)

## Files Created/Modified

- `opencode-widget/Sources/OpencodeWidgetShared/ProviderDisplayPreferences.swift` — typed non-secret display preferences, stable provider keys, and pure visible-card layout.
- `opencode-widget/Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift` — isolated acceptance coverage for persistence, recovery, ordering, idempotency, final selection, and charts-only mode.

## Decisions Made

- Used `object(forKey:) as? Bool ?? true` so missing, malformed, and legacy values never hide a provider card by accident.
- Kept provider order in `ProviderID.allCases`; filtering visibility cannot reorder, merge, or deduplicate providers.
- Restricted the shared layer to `Foundation` and Boolean presentation values; no cache, credential, chart, ledger, or network behavior changed.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The focused test build reports a pre-existing unused `withCString` result warning in `QuotaLedger.swift`; it is recorded in `deferred-items.md` and was not changed because it is unrelated to this plan.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The later Settings and menu-rendering plans can inject one `ProviderDisplayPreferences` instance and consume `ProviderCardLayout.visibleCards(preferences:)` without changing data collection behavior.
- Provider card visibility is now durable, isolated, and directly unit-tested.

## Self-Check: PASSED

- Confirmed both created Swift files exist.
- Confirmed task commits `6e1a1a4` and `dfdc216` exist in git history.

---

*Phase: 05-settings-provider-display-preferences*
*Completed: 2026-09-17*
