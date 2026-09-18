---
phase: 05-settings-provider-display-preferences
verified: 2026-09-18T11:47:49Z
status: passed
score: 7/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
prohibitions_verified: 4/4
gaps: []
deferred: []
---

# Phase 5: Settings: Provider Display Preferences — Verification Report

**Phase Goal:** Users can configure visible provider cards and securely connect their own provider accounts from a native Settings window, making the downloadable DMG usable without an existing OpenCode installation.
**Verified:** 2026-09-18T11:47:49Z
**Status:** passed
**Re-verification:** No — initial verification (no prior VERIFICATION.md existed)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | SETTINGS-01: The menu footer orders `Refresh`, `Settings`, `Quit`; Settings opens/focuses one native macOS Settings window. | ✓ VERIFIED | `OpencodeWidgetApp.swift:306-319` renders Refresh → `SettingsLink { Text("Settings") }` → Quit in order. `OpencodeWidgetApp.swift:46-48` `Settings { ProviderSettingsView(...) }` scene (native singleton, no `NSWindow`/`NSWindowController`). `ProviderSettingsTests.testFooterUsesNativeSettingsLinkBetweenRefreshAndQuit` passes. Human gate step 1 approved 2026-09-18. |
| 2 | SETTINGS-02: Independent DeepSeek/MiniMax/OpenAI toggles take effect immediately and persist across relaunch; missing/malformed/legacy stores default all visible. | ✓ VERIFIED | `ProviderDisplayPreferences.swift:26-40` reads `object(forKey:) as? Bool ?? true`, writes only the changed provider key, `@Observable` shares one instance with the menu. `ProviderDisplayPreferencesTests` (5 tests) cover default-visible, independent persistence, idempotency, final-write-wins. Human gate step 2 approved. |
| 3 | SETTINGS-03: Popover renders only enabled cards in fixed DeepSeek→MiniMax→OpenAI order and supports a charts-only layout with no blank container. | ✓ VERIFIED | `ProviderCardLayout.visibleCards` filters `ProviderID.allCases` (declared `deepseek, minimax, openAI` order, `ProviderDisplayPreferences.swift:4-18`). `OpencodeWidgetApp.swift:217-267` gates only the balance HStack and OpenAI card; charts (291-302) and footer (306-319) sit outside the visibility branches. `testVisibleCardsFilterEveryCombinationInFixedProviderOrder` + `testAllHiddenProvidersProduceAnEmptyChartsOnlyLayout` pass. Human gate step 2 approved. |
| 4 | SETTINGS-04: Card visibility affects presentation only; polling, cache, ledger, and chart inputs stay unchanged. | ✓ VERIFIED | `DataFetcher.refreshAll` (`DataFetcher.swift:126-180`) has no visibility/preference parameter or import; `AppDelegate.refreshData`/`MenuContent.refreshData` call it unconditionally. `testRefreshAllIgnoresAllCardVisibilityPreferences` iterates all 8 visibility combinations and asserts identical requests + cache/ledger/chart fields. Human gate step 3 approved. |
| 5 | SETTINGS-05: DeepSeek/MiniMax resolve independently, Keychain preferred over read-only legacy `auth.json`, which is never modified. | ✓ VERIFIED | `ProviderCredentialResolver.resolve` reads store first then `AuthReader.readLegacyKey` (`ProviderCredentialResolver.swift:17-22`); `AuthReader` has only `Data(contentsOf:)` reads for auth paths — no write path. `ProviderCredentialResolverTests` prove precedence, per-provider fallback, removal-to-fallback, byte-for-byte legacy immutability. Human gate step 4 approved. |
| 6 | SETTINGS-06: Settings validates each entered key against its provider before Keychain save; failed validation preserves the prior credential; secrets never logged/cached/persisted outside Keychain. | ✓ VERIFIED | `ProviderSetupCoordinator.save` (`ProviderSetupCoordinator.swift:133-154`) validates first, aborts on failure, upserts only on current-generation success. `DataFetcherProviderSetupValidator` routes DeepSeek→balance endpoint, MiniMax→usage endpoint, OpenAI→`false`. Tests cover independent saves, rollback, same-key stability, stale-generation rejection, redaction. Human gate steps 4/6 approved. |
| 7 | SETTINGS-07: OpenAI reports Connected/Not connected without exposing the token; copies exactly `codex login` without executing it; no platform API key accepted. | ✓ VERIFIED | `ProviderSetupCoordinator.swift:74,96` derive status from `AuthReader.hasUsableCodexSession()` (returns `Bool` only). `copyCodexLoginCommand()` writes literal `"codex login"` to the pasteboard (line 164-166). `ProviderSettingsView.swift:104-116` renders only status text + Copy button — no key field. `testCodexStatusUsesAvailabilityOnlyAndCopyWritesExactFixedCommand` passes; no `Process` in any phase-05 source. Human gate step 5 approved. |

**Score:** 7/7 truths verified (0 present, behavior-unverified)

### Prohibitions (must-NOT)

| Prohibition | Status | Evidence |
| --- | --- | --- |
| MUST NOT expose, log, cache, persist outside Keychain, or transmit a saved API key or Codex OAuth token. | ✓ VERIFIED | No `print`/`NSLog`/`os_log`/`Logger` in phase-05 sources; `ProviderCredentialStore` writes only `kSecValueData`; `ProviderCredentialResolver` has no persistence; `ProviderCredentialResolverTests.testResolutionDoesNotPersistSyntheticCredentialOutsideKeychain` asserts absence from defaults + cache fixture; `ProviderSettingsTests` assert status strings never contain the candidate. |
| MUST NOT write, delete, or alter `~/.local/share/opencode/auth.json`. | ✓ VERIFIED | Resolver/AuthReader expose read-only access; no `write(to:)`/`removeItem` on auth paths; `testRemovingOneKeychainCredentialRestoresOnlyThatLegacyFallbackWithoutMutatingFile` asserts `Data` equality pre/post. The only auth writes in the repo are in the pre-existing, non-shipped `OpencodeUsageTrackerApp` module (out of phase scope; see Anti-Patterns). |
| MUST NOT change polling, ledger/cache records, Refresh behaviour, chart data, or chart series because a card is hidden. | ✓ VERIFIED | `DataFetcher` has no visibility seam; `testRefreshAllIgnoresAllCardVisibilityPreferences` compares identical snapshots across all visibility states. |
| MUST NOT accept a platform OpenAI API key for ChatGPT Plus quota or run `codex login`. | ✓ VERIFIED | Validator returns `false` for `.openAI` (`ProviderSetupCoordinator.swift:25-26`); no OpenAI key control in `ProviderSettingsView`; OpenAI quota uses `chatgpt.com/backend-api/wham/usage` with the Codex OAuth Bearer token (`OpenAIQuotaFetcher.swift`), not `api.openai.com`. No `Process`/`NSTask` in phase-05 sources. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `Sources/OpencodeWidgetShared/ProviderDisplayPreferences.swift` | Typed preferences + pure layout | ✓ VERIFIED | 47 lines; `ProviderID`/`ProviderDisplayPreferences`/`ProviderCardLayout`; Foundation + Observation only. |
| `Sources/OpencodeWidgetShared/ProviderCredentialStore.swift` | Keychain adapter + stable identity | ✓ VERIFIED | 120 lines; generic-password update-then-add/read/delete; service `com.fathur6.opencode-widget.provider-credentials`; `Security` imported only here. |
| `Sources/OpencodeWidgetShared/ProviderCredentialResolver.swift` | Keychain-first resolver | ✓ VERIFIED | 23 lines; store read precedes matching legacy read; no write API. |
| `Sources/OpencodeWidgetShared/AuthReader.swift` | Narrow legacy + Codex status reader | ✓ VERIFIED | Added `readLegacyKey(for:authPath:)` and `hasUsableCodexSession(authPath:)`; existing contracts retained. |
| `Sources/OpencodeWidgetApp/DataFetcher.swift` | Independent resolver-backed refresh | ✓ VERIFIED | Optional `credentialResolver` seam; per-provider resolve; OpenAI/cache/ledger/chart semantics preserved. |
| `Sources/OpencodeWidgetApp/ProviderSettingsView.swift` | Compact native Providers UI | ✓ VERIFIED | 166 lines; 440 px bounded `ScrollView`; toggles, progressive `SecureField`, status, Remove, copy-only Codex. |
| `Sources/OpencodeWidgetApp/ProviderSetupCoordinator.swift` | Validation-before-save coordinator | ✓ VERIFIED | 173 lines; injected validator/store/pasteboard; per-provider generations; redacted status categories. |
| `Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift` | Settings scene + footer + conditional cards | ✓ VERIFIED | Shared `ProviderPresentationContext.preferences`; `SettingsLink`; visibility-gated cards. |
| `OpencodeWidgetApp.xcodeproj/project.pbxproj` | Provider sources registered | ✓ VERIFIED | All 5 new sources present in the Sources build phase; `xcodegen generate` reproduces the committed project with a clean `git status`. |
| `Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift` | SETTINGS-02/03 coverage | ✓ VERIFIED | 5 tests, passing. |
| `Tests/OpencodeWidgetSharedTests/ProviderCredentialResolverTests.swift` | SETTINGS-05 coverage | ✓ VERIFIED | 5 tests, passing. |
| `Tests/OpencodeWidgetAppTests/DataFetcherTests.swift` | SETTINGS-04 coverage | ✓ VERIFIED | 25 tests incl. display-isolation regression, passing. |
| `Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift` | SETTINGS-01/02/03/06/07 coverage | ✓ VERIFIED | 7 tests, passing. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| MenuContent | SwiftUI Settings scene | `SettingsLink` between Refresh and Quit | ✓ WIRED | `OpencodeWidgetApp.swift:46-48, 310-312`. |
| ProviderSettingsView | ProviderSetupCoordinator | Configure/Save/Remove + copy command | ✓ WIRED | `ProviderSettingsView.swift:71-116`. |
| ProviderSetupCoordinator | ProviderCredentialStore | successful validation precedes `upsert` | ✓ WIRED | `ProviderSetupCoordinator.swift:144-153`. |
| ProviderCredentialResolver | ProviderCredentialStore | store read before legacy read | ✓ WIRED | `ProviderCredentialResolver.swift:17-22`. |
| DataFetcher.refreshAll | ProviderCredentialResolver | one resolve per provider | ✓ WIRED | `DataFetcher.swift:145-149`. |
| ProviderDisplayPreferences | UserDefaults | `object(forKey:) as? Bool ?? true` + per-provider keys | ✓ WIRED | `ProviderDisplayPreferences.swift:26-40`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `MenuContent` balance/quota cards | `menuState.deepseekBalance` / `minimaxBalance` / `openAIQuota` | `MenuBarState.update(with:)` ← `DataFetcher.refreshAll()` → `DataStore.load/save` | Yes (provider HTTPS + cache merge) | ✓ FLOWING |
| `MenuContent` charts | `usageBuckets`, `balanceSnapshots`, `openAISnapshots` | `menuState.hourlyUsage` / history arrays (unchanged by visibility) | Yes | ✓ FLOWING |
| `ProviderSettingsView` toggles | `preferences.isCardVisible` | `ProviderDisplayPreferences` ← `UserDefaults.standard` | Yes (persisted Bool) | ✓ FLOWING |
| `ProviderSetupCoordinator` save | `credentialStore.upsert` | validated candidate → Keychain generic password | Yes (real Keychain; verified by approved human gate) | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused Provider suites (prefs, resolver, settings, refresh) | `swift test --scratch-path /tmp/opencode-widget-verify-05 --filter Provider` | 12 App + 13 Shared/Ledger/etc. executed, 0 failures | ✓ PASS |
| Full SwiftPM suite | `swift test --scratch-path /tmp/opencode-widget-verify-05` | 220 tests (68 Shared + 19 Ledger + 99 App + 34 UsageTracker), 0 failures | ✓ PASS |
| XcodeGen project regeneration | `xcodegen generate` | Project regenerated; `git status` clean (committed pbxproj matches spec) | ✓ PASS |
| Native Debug build | `xcodebuild -scheme OpencodeWidgetApp -configuration Debug build` | **BUILD SUCCEEDED** | ✓ PASS |
| Keychain secret non-persistence | `ProviderCredentialResolverTests`, `ProviderSettingsTests` | synthetic values absent from defaults/cache/status | ✓ PASS |

No probe scripts (`scripts/*/tests/probe-*.sh`) are declared or present; probe execution is not applicable to this Swift/XCTest phase.

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| SETTINGS-01 | 05-04, 05-05 | Footer order + native singleton Settings window. | ✓ SATISFIED | Truth 1; footer test; human gate step 1. |
| SETTINGS-02 | 05-01, 05-04, 05-05 | Independent persisted visibility toggles, default visible. | ✓ SATISFIED | Truth 2; preferences tests; human gate step 2. |
| SETTINGS-03 | 05-01, 05-04, 05-05 | Enabled-only fixed-order cards, charts-only layout. | ✓ SATISFIED | Truth 3; layout + menu tests; human gate step 2. |
| SETTINGS-04 | 05-03, 05-05 | Visibility is presentation-only. | ✓ SATISFIED | Truth 4; display-isolation regression; human gate step 3. |
| SETTINGS-05 | 05-02, 05-05 | Keychain-first, read-only legacy fallback. | ✓ SATISFIED | Truth 5; resolver tests; human gate step 4. |
| SETTINGS-06 | 05-04, 05-05 | Validate-before-save, rollback, secret containment. | ✓ SATISFIED | Truth 6; settings tests; human gate steps 4/6. |
| SETTINGS-07 | 05-04, 05-05 | Codex status + copy-only guidance, no token exposure. | ✓ SATISFIED | Truth 7; Codex test; human gate step 5. |

**Orphaned requirements:** None. All 7 IDs mapped to Phase 5 in `REQUIREMENTS.md` appear in at least one plan's `requirements` frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| — | — | No `TBD`/`FIXME`/`XXX`/`TODO`/`PLACEHOLDER` markers, no empty/stub returns, no hardcoded-empty render data in any phase-05 source. | — | None. |
| `Sources/OpencodeWidgetLedger/QuotaLedger.swift` | 105 | Pre-existing unused `withCString` warning (not modified by this phase; not a debt marker). | ℹ️ Info | Tracked in `deferred-items.md`; does not affect the build or suite. |
| `Sources/OpencodeUsageTrackerApp/ViewModels/OnboardingViewModel.swift` | 49 | Pre-existing `data.write(to:)` to `auth.json` in the separate, non-shipped `OpencodeUsageTrackerApp` target (not in phase-05 file range). | ℹ️ Info | Outside Phase 5 scope; the `OpencodeWidgetApp` target contains no auth-file write path. |

### Human Verification (previously approved — not outstanding)

The phase's blocking human gate (05-05 Task 2) was executed and approved by Aman on 2026-09-18, covering:

1. Singleton bounded native Settings window and footer order — approved.
2. Independent card toggles persisting across relaunch, fixed order, charts-only mode — approved.
3. Live refresh/chart content unaffected by toggling cards — approved.
4. Live per-provider Keychain setup, invalid-replacement rollback, unchanged legacy fallback — approved.
5. Codex Connected/Not connected and exact `codex login` pasteboard copy with no auth launch — approved.
6. No secret visible in Settings UI or cache/ledger; Keychain metadata inspected only — approved.

These items cannot be faithfully asserted from XCTest and are therefore carried by the approved human gate rather than re-requested here.

### Non-Blocking Observations

- The Settings row status is in-memory: `ProviderSetupCoordinator.setupStatuses` starts empty and does not query the store on launch, so an already-Keychain-configured provider reads "Not configured" until re-saved. Credential resolution and refresh still work correctly (the resolver reads the store), and no acceptance criterion or must-have requires persisted status display. Not a gap.
- A successfully saved candidate remains in the in-memory `candidateKeys` map (masked by `SecureField`) until the row is collapsed; it is never persisted, logged, or transmitted beyond the provider validation endpoint. Not a gap.

### Gaps Summary

No gaps. Every SPEC requirement, acceptance criterion, and declared prohibition is backed by source evidence plus passing automated coverage, with the non-automatable native behaviors carried by the approved human gate. The full 220-test SwiftPM suite is green, the XcodeGen Debug build succeeds, and no unresolved debt marker or stubbed implementation exists in the phase scope.

---

_Verified: 2026-09-18T11:47:49Z_
_Verifier: the agent (gsd-verifier)_
