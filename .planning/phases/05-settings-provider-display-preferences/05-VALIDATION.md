---
phase: 05
slug: settings-provider-display-preferences
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-17
---

# Phase 05 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest through SwiftPM test targets |
| **Config file** | `opencode-widget/Package.swift` |
| **Quick run command** | `cd opencode-widget && swift test --filter Provider` |
| **Full suite command** | `cd opencode-widget && swift test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd opencode-widget && swift test --filter Provider`
- **After every plan wave:** Run `cd opencode-widget && swift test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement(s) | Threat Ref | Secure / Required Behavior | Test Type | Test File | Automated Command | File Exists | Status |
|---------|------|------|----------------|------------|----------------------------|-----------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | SETTINGS-02, SETTINGS-03 | T-05-01, T-05-02 | Specify isolated default-visible recovery, independent persistence, fixed order, and charts-only layout for non-secret preferences. | XCTest unit (RED) | `Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift` | `rm -rf /tmp/opencode-widget-phase05-01 && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-01 --filter ProviderDisplayPreferencesTests` | No — created by this task | pending |
| 05-01-02 | 01 | 1 | SETTINGS-02, SETTINGS-03 | T-05-01, T-05-02 | Make the display preference and layout contract green without any credential, cache, ledger, chart, or network dependency. | XCTest unit (GREEN) | `Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift` | `rm -rf /tmp/opencode-widget-phase05-01 && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-01 --filter ProviderDisplayPreferencesTests` | Created by 05-01-01 | pending |
| 05-02-01 | 02 | 1 | SETTINGS-05 | T-05-03, T-05-04, T-05-05 | Specify Keychain-first precedence, independent legacy fallback/removal, legacy byte immutability, and absence of synthetic secrets from non-Keychain fixtures. | XCTest unit (RED) | `Tests/OpencodeWidgetSharedTests/ProviderCredentialResolverTests.swift` | `rm -rf /tmp/opencode-widget-phase05-02 && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-02 --filter ProviderCredentialResolverTests` | No — created by this task | pending |
| 05-02-02 | 02 | 1 | SETTINGS-05 | T-05-03, T-05-04, T-05-05 | Make the stable Keychain store and read-only, per-provider resolver contract green while keeping secrets out of cache/defaults/ledger. | XCTest unit (GREEN) | `Tests/OpencodeWidgetSharedTests/ProviderCredentialResolverTests.swift` | `rm -rf /tmp/opencode-widget-phase05-02 && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-02 --filter ProviderCredentialResolverTests` | Created by 05-02-01 | pending |
| 05-03-01 | 03 | 2 | SETTINGS-04 | T-05-06, T-05-07 | Specify DeepSeek-only and MiniMax-only refreshes plus unchanged requests, cache, ledger-ready fields, and chart inputs across display states. | XCTest integration-style unit (RED) | `Tests/OpencodeWidgetAppTests/DataFetcherTests.swift` | `rm -rf /tmp/opencode-widget-phase05-03 && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-03 --filter DataFetcherTests` | Yes — modified by this task | pending |
| 05-03-02 | 03 | 2 | SETTINGS-04 | T-05-06, T-05-07 | Make independent resolver-backed collection green while visibility remains absent from refresh APIs and existing OpenAI/cache/ledger/chart behavior remains unchanged. | XCTest integration-style unit (GREEN) | `Tests/OpencodeWidgetAppTests/DataFetcherTests.swift` | `rm -rf /tmp/opencode-widget-phase05-03 && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-03 --filter DataFetcherTests` | Yes — modified by this task | pending |
| 05-04-01 | 04 | 2 | SETTINGS-01, SETTINGS-02, SETTINGS-03, SETTINGS-06, SETTINGS-07 | T-05-08, T-05-09, T-05-10, T-05-11 | Specify native Settings footer/order, immediate card selection, selected-provider validation-before-save, rollback/generation safety, redacted state, and copy-only Codex guidance. | `@MainActor` XCTest async unit (RED) | `Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift` | `rm -rf /tmp/opencode-widget-phase05-04 && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-04 --filter ProviderSettingsTests` | No — created by this task | pending |
| 05-04-02 | 04 | 2 | SETTINGS-01, SETTINGS-02, SETTINGS-03, SETTINGS-06, SETTINGS-07 | T-05-08, T-05-09, T-05-10, T-05-11 | Make native Settings composition and the per-provider coordinator green, retaining Keychain-only secret storage and no process-based Codex authentication. | `@MainActor` XCTest async unit (GREEN) | `Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift` | `rm -rf /tmp/opencode-widget-phase05-04 && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-04 --filter ProviderSettingsTests` | Created by 05-04-01 | pending |
| 05-05-01 | 05 | 3 | SETTINGS-01, SETTINGS-02, SETTINGS-03, SETTINGS-04, SETTINGS-05, SETTINGS-06, SETTINGS-07 | T-05-01 through T-05-11 | Run the focused Provider suites and complete SwiftPM suite; halt on a failure rather than weakening a requirement. | phase-wide automated regression | `ProviderDisplayPreferencesTests`, `ProviderCredentialResolverTests`, `DataFetcherTests`, `ProviderSettingsTests`, plus full suite | `rm -rf /tmp/opencode-widget-phase05-final && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-final --filter Provider && swift test --scratch-path /tmp/opencode-widget-phase05-final` | Created/updated by Plans 01–04 | pending |
| 05-05-02 | 05 | 3 | SETTINGS-01, SETTINGS-02, SETTINGS-03, SETTINGS-04, SETTINGS-05, SETTINGS-06, SETTINGS-07 | T-05-12, T-05-13 | Gate actual native window behavior, Keychain metadata, live independent setup/rollback, legacy fallback, and copy-only Codex behavior without placing secrets in evidence. | automated build + blocking human verification | Phase-wide suites and application build | `rm -rf /tmp/opencode-widget-phase05-final && cd opencode-widget && swift test --scratch-path /tmp/opencode-widget-phase05-final --filter Provider && swift test --scratch-path /tmp/opencode-widget-phase05-final && xcodegen generate && xcodebuild -scheme OpencodeWidgetApp -configuration Debug build` | Created/updated by Plans 01–04 | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] `opencode-widget/Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift` - SETTINGS-02 and SETTINGS-03 behavior.
- [ ] `opencode-widget/Tests/OpencodeWidgetSharedTests/ProviderCredentialResolverTests.swift` - SETTINGS-05 with in-memory secret-store fake and immutable legacy fixture.
- [ ] `opencode-widget/Tests/OpencodeWidgetAppTests/DataFetcherTests.swift` additions - SETTINGS-04 through injected resolver, `MockURLProtocol`, and data-path output comparison.
- [ ] `opencode-widget/Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift` - SETTINGS-01, SETTINGS-02, SETTINGS-03, SETTINGS-06, and SETTINGS-07 through injected validator, pasteboard, and process-free doubles.

Existing SwiftPM test targets and URLProtocol-based request injection cover the rest of the test infrastructure.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Native settings window focus and bounded scrolling | SETTINGS-01 | XCTest cannot reliably assert native macOS window focus and size behavior | Open Settings repeatedly, confirm one focused window; expand rows and confirm content scrolls in the bounded window. |
| Live provider validation and Keychain persistence | SETTINGS-05, SETTINGS-06 | Requires Aman-supplied provider credentials and macOS Keychain inspection | Configure each provider with a valid key, relaunch, confirm data refreshes; test an invalid replacement and verify the prior connection remains. |
| Codex connected-state setup guidance | SETTINGS-07 | Requires an actual local Codex session | With and without a valid `~/.codex/auth.json`, confirm status changes and the copy action places exactly `codex login` on the pasteboard. |

---

## Validation Sign-Off

- [ ] All tasks have automated verification or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30 seconds
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
