---
phase: 05-settings-provider-display-preferences
plan: 04
subsystem: native-provider-settings
tags: [swift, swiftui, macos, settingslink, keychain, observation, xctest]
requires:
  - phase: 05-01
    provides: Typed provider visibility preferences and fixed card layout
  - phase: 05-02
    provides: Injectable Keychain credential store and status-only Codex availability
provides:
  - Native singleton Providers Settings scene and SettingsLink footer action
  - Immediate persisted card visibility with charts-only menu rendering
  - Per-provider validation-before-Keychain-save setup and copy-only Codex guidance
affects: [05-05, menu-content, provider-credentials, native-settings]
tech-stack:
  added: []
  patterns: [shared observable presentation model, per-provider save generation, injected validator/store/pasteboard seams]
key-files:
  created:
    - opencode-widget/Sources/OpencodeWidgetApp/ProviderSettingsView.swift
    - opencode-widget/Sources/OpencodeWidgetApp/ProviderSetupCoordinator.swift
    - opencode-widget/Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift
  modified:
    - opencode-widget/Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift
    - opencode-widget/Sources/OpencodeWidgetShared/ProviderDisplayPreferences.swift
key-decisions:
  - "Use SwiftUI Settings and SettingsLink rather than custom AppKit settings-window ownership."
  - "Keep candidate credentials local to validation and Keychain upsert calls; observable state contains only redacted categories."
  - "Make display preferences observable so Settings toggles update the already-open menu immediately while persistence remains presentation-only."
patterns-established:
  - "Native Settings receives the same ProviderDisplayPreferences instance as MenuContent."
  - "Provider setup uses injected async validator, Keychain store, and pasteboard seams with per-provider generations."
requirements-completed: [SETTINGS-01, SETTINGS-02, SETTINGS-03, SETTINGS-06, SETTINGS-07]
coverage:
  - id: D1
    description: Native footer SettingsLink ordering and shared immediate visible-card selection, including charts-only output.
    requirement: SETTINGS-01
    verification:
      - kind: unit
        ref: opencode-widget/Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift#testFooterUsesNativeSettingsLinkBetweenRefreshAndQuit
        status: pass
      - kind: unit
        ref: opencode-widget/Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift#testVisibleCardsFollowInjectedPreferencesImmediatelyAndSupportChartsOnly
        status: pass
    human_judgment: true
    rationale: Native window focus reuse and compact visual layout require macOS UI review.
  - id: D2
    description: Independent DeepSeek and MiniMax validation-before-save, rollback, generation ordering, and removal.
    requirement: SETTINGS-06
    verification:
      - kind: unit
        ref: opencode-widget/Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift#ProviderSettingsTests
        status: pass
    human_judgment: false
  - id: D3
    description: Status-only Codex connection guidance copies exactly the fixed command without starting authentication.
    requirement: SETTINGS-07
    verification:
      - kind: unit
        ref: opencode-widget/Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift#testCodexStatusUsesAvailabilityOnlyAndCopyWritesExactFixedCommand
        status: pass
    human_judgment: false
metrics:
  duration: 8 min
  completed: 2026-09-18
  tasks_completed: 2
  files_modified: 5
status: complete
---

# Phase 05 Plan 04: Native Provider Settings Summary

**A compact 440 px native Providers Settings page now shares immediate card visibility with the menu, validates each provider before Keychain replacement, and gives OpenAI copy-only Codex status guidance.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-17T22:55:40Z
- **Completed:** 2026-09-17T23:03:49Z
- **Tasks:** 2/2
- **Files modified:** 5

## Accomplishments

- Added the native `Settings` scene and a labelled `SettingsLink` between Refresh and Quit without custom window lifecycle code.
- Added a bounded, scrollable Providers page in fixed DeepSeek, MiniMax, OpenAI order, with standard toggles, progressive secure setup, remove actions, and charts-only menu support.
- Added an injected setup coordinator that validates only the selected provider before Keychain upsert, rejects stale save generations, publishes redacted categories, and uses pasteboard-only `codex login` guidance.

## Verification

- RED: `rm -rf /tmp/opencode-widget-phase05-04 && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-04 --filter ProviderSettingsTests` failed as intended until the Settings helpers and coordinator existed.
- GREEN: the same focused suite passed with 7 `ProviderSettingsTests` and 0 failures.
- Full gate: `rm -rf /tmp/opencode-widget-phase05-04 && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-04` passed: 220 XCTest cases with 0 failures.
- Static audit found `SettingsLink`, `SecureField`, Keychain-backed store injection, and the exact `codex login` pasteboard command; it found no `Process`, `NSWindow`, `NSWindowController`, plaintext-token UI, or stub markers in the changed settings sources.
- The build retains the pre-existing unrelated `QuotaLedger.swift` unused-`withCString` result warning.

## Task Commits

1. **Task 1: Specify native Settings, validation-before-save, and Codex guidance** — `0a7ea4d` (`test`)
2. **Task 2: Wire the compact Providers page and secure setup coordinator** — `c9d380f` (`feat`)

## Files Created/Modified

- `opencode-widget/Sources/OpencodeWidgetApp/ProviderSettingsView.swift` — compact scrollable native provider controls and copy-only Codex guidance.
- `opencode-widget/Sources/OpencodeWidgetApp/ProviderSetupCoordinator.swift` — injectable redacted validation, Keychain setup, generation, and pasteboard coordination.
- `opencode-widget/Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift` — shared preferences injection, conditional card rendering, Settings scene, and footer SettingsLink.
- `opencode-widget/Sources/OpencodeWidgetShared/ProviderDisplayPreferences.swift` — observable persisted visibility state for immediate menu updates.
- `opencode-widget/Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift` — red/green contract for ordering, visibility, save safety, redaction, and Codex copy behavior.

## Decisions Made

- Used native SwiftUI `Settings`/`SettingsLink` for singleton settings-window behavior rather than AppKit window ownership.
- Kept API-key strings local to secure-field submission, validator, and Keychain upsert; UI state exposes only fixed status categories.
- Extended the existing presentation preference model with Observation so a shared instance updates MenuContent immediately, without coupling visibility to refresh, cache, ledger, or charts.

## TDD Gate Compliance

- RED commit `0a7ea4d` precedes GREEN commit `c9d380f` in git history.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Made shared display preferences observable**
- **Found during:** Task 2
- **Issue:** The existing typed preference facade persisted values but did not publish changes, so an already-open menu could not reliably redraw immediately after a Settings toggle.
- **Fix:** Added `@Observable` in-memory visibility state synchronized to the same non-secret UserDefaults keys and injected that shared instance into both native surfaces.
- **Files modified:** `opencode-widget/Sources/OpencodeWidgetShared/ProviderDisplayPreferences.swift`, `opencode-widget/Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift`
- **Verification:** `ProviderSettingsTests.testVisibleCardsFollowInjectedPreferencesImmediatelyAndSupportChartsOnly` and the full Swift suite pass.
- **Committed in:** `c9d380f`

---

**Total deviations:** 1 auto-fixed (1 missing critical functionality).
**Impact on plan:** Necessary to satisfy immediate persisted card visibility; it remains presentation-only and adds no data-path or secret-storage scope.

## Issues Encountered

- The first GREEN build correctly rejected a global mutable observable preference instance under Swift 6 concurrency checking; it was isolated to `MainActor`, matching the SwiftUI presentation boundary.
- The full build continues to emit the unrelated existing `QuotaLedger.swift` unused-result warning.

## Known Stubs

None.

## User Setup Required

None - no external service configuration is required. Users who need ChatGPT Plus quota guidance can copy `codex login`; the app never launches or authenticates Codex itself.

## Next Phase Readiness

- Native settings, presentation isolation, and secure provider setup are ready for the final Phase 05 verification and manual macOS visual check.
- Manual UAT should confirm repeated SettingsLink activation fronts one Providers window and expanded rows remain comfortably scrollable at the compact width.

## Self-Check: PASSED

- Confirmed `ProviderSettingsView.swift`, `ProviderSetupCoordinator.swift`, and `ProviderSettingsTests.swift` exist.
- Confirmed task commits `0a7ea4d` and `c9d380f` exist in git history.

---
*Phase: 05-settings-provider-display-preferences*
*Completed: 2026-09-18*
