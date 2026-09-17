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

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | SETTINGS-02, SETTINGS-03 | -- | Default-visible persisted card preferences are presentation-only | unit | `swift test --filter ProviderDisplayPreferencesTests` | No, Wave 0 | pending |
| 05-01-02 | 01 | 1 | SETTINGS-05 | T-05-01 | Keychain takes precedence; legacy values are read-only fallbacks | unit | `swift test --filter ProviderCredentialResolverTests` | No, Wave 0 | pending |
| 05-02-01 | 02 | 2 | SETTINGS-01, SETTINGS-04 | -- | Settings opens natively; visibility does not alter collection or charts | unit and integration-style | `swift test --filter ProviderSettingsTests` | No, Wave 0 | pending |
| 05-02-02 | 02 | 2 | SETTINGS-06, SETTINGS-07 | T-05-01, T-05-02, T-05-03 | Validate before Keychain save; status-only Codex guidance; no secret or process use | async unit | `swift test --filter ProviderSetupCoordinatorTests` | No, Wave 0 | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] `opencode-widget/Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift` - SETTINGS-02 and SETTINGS-03 behavior.
- [ ] `opencode-widget/Tests/OpencodeWidgetSharedTests/ProviderCredentialResolverTests.swift` - SETTINGS-05 with in-memory secret-store fake and immutable legacy fixture.
- [ ] `opencode-widget/Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift` - SETTINGS-01, SETTINGS-04, SETTINGS-06, and SETTINGS-07 through injected validator, pasteboard, and process-free doubles.

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
