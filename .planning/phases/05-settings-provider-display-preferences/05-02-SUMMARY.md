---
phase: 05-settings-provider-display-preferences
plan: 02
subsystem: credential-security
tags: [swift, macos, keychain, security, credentials, testing]
requires:
  - phase: 05-01
    provides: ProviderID identifiers shared by provider settings work
provides:
  - Injectable generic-password Keychain storage with stable provider identities
  - Independent Keychain-first provider credential resolution with read-only legacy fallback
  - Focused regression coverage for precedence, fallback, removal, immutability, and persistence boundaries
affects: [05-03, 05-04, provider-refresh, provider-settings]
tech-stack:
  added: []
  patterns: [generic-password Keychain update-then-add, per-provider Keychain-first resolver, read-only legacy auth fallback]
key-files:
  created:
    - opencode-widget/Sources/OpencodeWidgetShared/ProviderCredentialStore.swift
    - opencode-widget/Sources/OpencodeWidgetShared/ProviderCredentialResolver.swift
    - opencode-widget/Tests/OpencodeWidgetSharedTests/ProviderCredentialResolverTests.swift
  modified:
    - opencode-widget/Sources/OpencodeWidgetShared/AuthReader.swift
key-decisions:
  - "Use explicit, release-stable service and account constants for generic-password Keychain items rather than UI-derived names."
  - "Resolve each provider independently from Keychain first, then read only its matching legacy auth value without legacy mutation APIs."
patterns-established:
  - "ProviderCredentialStore: injected async Keychain boundary with Security calls detached from MainActor and redacted status failures."
  - "ProviderCredentialResolver: one-provider lookup that keeps legacy auth.json read-only and out of non-Keychain persistence."
requirements-completed: [SETTINGS-05]
coverage:
  - id: D1
    description: "Keychain-first, independent DeepSeek and MiniMax resolution with read-only legacy fallback and removal-to-fallback behavior."
    requirement: SETTINGS-05
    verification:
      - kind: unit
        ref: "swift test --scratch-path /tmp/opencode-widget-phase05-02 --filter ProviderCredentialResolverTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Stable generic-password Keychain identity and background Security adapter with redacted failure categories."
    requirement: SETTINGS-05
    verification:
      - kind: unit
        ref: "ProviderCredentialResolverTests plus static source audit of ProviderCredentialStore.swift"
        status: pass
    human_judgment: false
duration: 12min
completed: 2026-09-18
status: complete
---

# Phase 05 Plan 02: Keychain-First Credential Resolution Summary

**Stable macOS Keychain storage resolves DeepSeek and MiniMax credentials independently before preserving a byte-for-byte read-only legacy OpenCode fallback.**

## Performance

- **Duration:** 12 min recovery audit and completion metadata
- **Started:** 2026-09-18T06:30:00Z
- **Completed:** 2026-09-18T06:42:00Z
- **Tasks:** 2 completed in existing authoritative commits
- **Files modified:** 4

## Accomplishments

- Audited the committed TDD contract for provider-specific Keychain precedence, independent fallback, removal-to-fallback, invalid input, legacy-file immutability, and non-Keychain persistence boundaries.
- Confirmed the production adapter uses explicit generic-password service/account identifiers, update-then-add replacement, idempotent removal, and non-MainActor Security work.
- Confirmed the resolver has no legacy write path and calls the narrow matching legacy reader only after the store does not supply a value.

## Task Commits

Each task was committed atomically before recovery:

1. **Task 1: Specify Keychain-first resolution and immutable legacy fallback** - `75c4d7d` (test)
2. **Task 2: Implement stable Keychain storage and per-provider read-only resolution** - `1aa18d9` (feat)

## Files Created/Modified

- `opencode-widget/Sources/OpencodeWidgetShared/ProviderCredentialStore.swift` - Injectable generic-password Keychain protocol, stable identity, and async production adapter.
- `opencode-widget/Sources/OpencodeWidgetShared/ProviderCredentialResolver.swift` - Per-provider Keychain-first resolution with no legacy mutation path.
- `opencode-widget/Sources/OpencodeWidgetShared/AuthReader.swift` - Narrow legacy provider reader and status-only Codex session check while retaining existing reader contracts.
- `opencode-widget/Tests/OpencodeWidgetSharedTests/ProviderCredentialResolverTests.swift` - In-memory-store and temporary-file regression coverage without Keychain or network access.

## Decisions Made

- Kept the service and account values explicit and independent of UI labels so released Keychain entries retain a stable identity.
- Kept credential values local to Keychain/resolver calls; persisted cache, preferences, status strings, logs, and the legacy auth file remain outside the credential boundary.

## Verification

- `swift test --scratch-path /tmp/opencode-widget-phase05-02 --filter ProviderCredentialResolverTests` — passed (5 tests).
- `git diff --check 75c4d7d^ 75c4d7d` and `git diff --check 1aa18d9^ 1aa18d9` — passed.
- Static source audit confirmed `Security` is imported only by `ProviderCredentialStore.swift`, where generic-password operations use the prescribed stable service/account constants; the resolver and legacy reader contain no persistence or logging calls.

## Deviations from Plan

None - the interrupted executor had already completed and committed both planned TDD tasks. This recovery audited those commits and completed the missing summary and metadata only.

## Issues Encountered

- The targeted build emitted a pre-existing unused-result warning in `QuotaLedger.swift`; it is outside this plan's credential boundary and did not affect the focused suite.

## User Setup Required

None - no external service configuration was required for the automated resolver coverage.

## Next Phase Readiness

- The shared Keychain and resolver boundary is ready for 05-03 to inject into independent provider collection and for 05-04 to use for validate-before-save setup.
- No credential values are included in this summary, test output, preferences, cache fixtures, errors, or legacy auth files.

## Self-Check: PASSED

- Required source and test files exist at the paths listed above.
- Authoritative task commits `75c4d7d` and `1aa18d9` exist in repository history.

---
*Phase: 05-settings-provider-display-preferences*
*Completed: 2026-09-18*
