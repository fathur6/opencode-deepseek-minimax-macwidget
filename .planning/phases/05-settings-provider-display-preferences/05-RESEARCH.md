# Phase 05: Settings: Provider Display Preferences - Research

**Researched:** 2026-09-17  
**Domain:** Native macOS SwiftUI settings, Keychain-backed provider credentials, and presentation-only preferences  
**Confidence:** LOW — direct Apple documentation was retrieved, but the required research seam classified the available `webfetch` provider as LOW; Context7 and web search were unavailable in this session.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Settings layout
- **D-01:** Use one compact native macOS `Providers` settings page, not tabs or a sidebar.
- **D-02:** Represent DeepSeek, MiniMax, and OpenAI as compact provider rows. Each row includes card visibility and connection status; DeepSeek and MiniMax expand in place only when the user chooses Configure.
- **D-03:** Preserve the widget's monochrome visual language while using standard macOS controls for toggles, fields, and buttons.
- **D-04:** Start Settings at an approximately 440 px width with a sensible minimum. Keep the window bounded; expanded provider content scrolls instead of requiring an expansive or fully resizable layout.

### the agent's Discretion
- Select the native AppKit/SwiftUI mechanism that opens or focuses the singleton Settings window.
- Choose exact Keychain service/account identifiers, preference key names, and migration implementation while meeting the Keychain-first/read-only-fallback contract in `05-SPEC.md`.
- Define validation progress/error copy, new-user popover messaging, and Codex status microcopy within the security and behaviour constraints in `05-SPEC.md`.

### Deferred Ideas (OUT OF SCOPE)
None - discussion stayed within phase scope. Chart customization, card arrangement, currency controls, refresh configuration, and data management remain explicitly deferred by `05-SPEC.md`.
</user_constraints>

## Project Constraints (from AGENTS.md)

- Use the existing Swift 5.9+ / SwiftUI / macOS 14+ / XcodeGen stack; do not introduce a new build system. [CITED: AGENTS.md]
- Keep this a menu-bar app; a WidgetKit extension is outside the current scope. [CITED: AGENTS.md]
- Preserve the established black-and-white monochrome aesthetic. [CITED: AGENTS.md]
- The phase is in the active GSD planning workflow; research may write planning artifacts but must not edit application code. [CITED: AGENTS.md]
- No project-defined skills or `rules/*.md` files exist, so no additional project skill rules apply. [CITED: project skills discovery + repository glob]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SETTINGS-01 | Native Settings action opens/focuses one settings window. | Use the existing `Settings` scene and a footer `SettingsLink`; Apple documents it orders an already-open settings window front. |
| SETTINGS-02 | Independent, persisted, default-visible card toggles. | Use a dedicated, injectable UserDefaults-backed presentation model with type-checked reads and per-provider keys. |
| SETTINGS-03 | Render enabled cards in fixed order; support charts-only mode. | Derive a pure `ProviderCardLayout` from preferences; conditionally omit the balance row rather than rendering an empty container. |
| SETTINGS-04 | Visibility never changes polling, cache, ledger, or charts. | Keep preference reads exclusively in `MenuContent`; do not pass visibility into `DataFetcher`, ledger, or chart services. |
| SETTINGS-05 | Keychain-first, read-only legacy credential fallback. | Resolve each provider independently: app Keychain secret first, then a single-provider read of legacy `auth.json`; never write that file. |
| SETTINGS-06 | Validate separately, then securely save/remove DeepSeek/MiniMax keys. | Validate candidate only against its provider endpoint; commit to Keychain only after success and use per-provider save generations. |
| SETTINGS-07 | Report Codex availability and copy `codex login` only. | Add a boolean session-availability helper and copy a literal command via pasteboard; do not accept an OpenAI platform key or launch a process. |
</phase_requirements>

## Summary

Use SwiftUI's existing `Settings` scene, replacing its current `EmptyView`, and place a labelled `SettingsLink` in the menu footer between Refresh and Quit. `SettingsLink` is the native singleton mechanism: Apple documents that it opens the Settings scene or brings its existing window to the front on macOS. This avoids a custom `NSWindowController` and duplicate-window bookkeeping. [CITED: https://developer.apple.com/documentation/swiftui/settingslink.md]

Separate the phase into three deliberately narrow state layers: (1) non-secret card visibility in `UserDefaults`, (2) secrets in a `Security`-framework generic-password Keychain store, and (3) a resolver that reads Keychain first and the existing OpenCode JSON only as a read-only per-provider fallback. Apple explicitly describes UserDefaults as unencrypted disk storage for non-sensitive configuration and Keychain Services as encrypted storage for small secrets. [CITED: https://developer.apple.com/documentation/foundation/userdefaults.md] [CITED: https://developer.apple.com/documentation/security/keychain-services.md]

The essential implementation change is not just a Settings view: current `DataFetcher.refreshAll()` accepts an all-or-nothing `AuthCredentials` object, so a Keychain-only DeepSeek account cannot work unless MiniMax is also present. Refactor credential resolution to be per provider and preserve the current independent collection, cache, ledger, and charts flow. Visibility must be consumed only by rendering/layout code. [CITED: opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift]

**Primary recommendation:** Use `SettingsLink` + one shared observable, injectable display-preferences model + an injected Keychain-backed per-provider credential resolver; never route secrets or visibility into `DataStore`, `WidgetCache`, or ledger/chart inputs.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Open/focus Providers settings | Browser / Client (native macOS UI) | — | SwiftUI owns the existing `Settings` scene and its presentation action. [CITED: https://developer.apple.com/documentation/swiftui/settings.md] |
| Provider-card visibility persistence | Browser / Client (native macOS UI) | Database / Storage (UserDefaults) | Visibility is non-secret presentation state that must survive relaunch but must not affect collection. [CITED: https://developer.apple.com/documentation/foundation/userdefaults.md] |
| DeepSeek/MiniMax secret storage and resolution | Database / Storage (macOS Keychain) | API / Backend (provider HTTPS validation) | Keychain holds the secret; validation sends a candidate only to the selected provider endpoint. [CITED: 05-SPEC.md] |
| Legacy OpenCode migration fallback | API / Backend (credential resolution) | Database / Storage (read-only file) | Resolver chooses the Keychain item first, then reads only the matching legacy JSON value. [CITED: 05-SPEC.md] |
| Polling, cache, ledger, and charts | API / Backend (existing app data path) | Database / Storage | These are existing data responsibilities and must not receive display preferences. [CITED: 05-SPEC.md] [CITED: opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift] |
| Codex setup status and copy guidance | Browser / Client (native macOS UI) | Database / Storage (read-only Codex auth file) | UI displays only a boolean status and copies a literal command; it does not authenticate. [CITED: 05-SPEC.md] |

## Standard Stack

### Core

| Library / framework | Version | Purpose | Why Standard |
|---------------------|---------|---------|--------------|
| SwiftUI `Settings` + `SettingsLink` | macOS 14+ | Native Providers page and singleton settings presentation | The app already declares a `Settings { EmptyView() }` scene; `SettingsLink` explicitly opens or fronts that scene. [CITED: https://developer.apple.com/documentation/swiftui/settings.md] [CITED: https://developer.apple.com/documentation/swiftui/settingslink.md] |
| Foundation `UserDefaults` | macOS 14+ | Persist three non-secret visibility Booleans | It is Apple's persistent app-settings store and is documented as thread-safe; it must not hold secrets. [CITED: https://developer.apple.com/documentation/foundation/userdefaults.md] |
| Security Keychain Services | macOS 14+ | Encrypt DeepSeek/MiniMax API keys in generic-password items | Apple's built-in encrypted store for small secrets; no external credential dependency is necessary. [CITED: https://developer.apple.com/documentation/security/keychain-services.md] |
| Foundation `URLSession` | existing | Validate candidates through existing provider endpoints | `DataFetcher` already uses injected sessions and existing DeepSeek/MiniMax endpoint functions. [CITED: opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift] |
| XCTest via SwiftPM | Swift tools 6.3 manifest / macOS 14 target | Unit and integration-style verification | Existing `Package.swift` defines app/shared test targets and existing tests use `URLProtocol` injection. [CITED: opencode-widget/Package.swift] [CITED: opencode-widget/Tests/OpencodeWidgetAppTests/DataFetcherTests.swift] |

### Supporting

| Library / framework | Version | Purpose | When to Use |
|---------------------|---------|---------|-------------|
| AppKit `NSPasteboard` | system | Copy the fixed `codex login` command | Use only for the copy action; do not use `Process`, `NSWorkspace.openApplication`, or Terminal automation. [CITED: 05-SPEC.md] |
| Swift Observation (`@Observable`, `@State`) | existing macOS 14 stack | Share immediate visibility changes between MenuContent and Settings | Use for the in-process presentation model while UserDefaults provides relaunch persistence. [CITED: opencode-widget/Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `SettingsLink` | `@Environment(\.openSettings)` + a Button | Apple supports both; choose `SettingsLink` because it already guarantees opening/fronting the Settings scene without a custom action. `openSettings` is only useful if a normal Button action is structurally required. [CITED: https://developer.apple.com/documentation/swiftui/environmentvalues/opensettings.md] |
| Generic-password Keychain item | API key in `UserDefaults`/`DataStore`/JSON | Prohibited: Apple documents defaults as unencrypted and unsuitable for sensitive data. [CITED: https://developer.apple.com/documentation/foundation/userdefaults.md] |
| Per-provider credential resolver | Extend `AuthCredentials` all-or-nothing parsing | The latter preserves the current hard gate and breaks independent DeepSeek/MiniMax setup. [CITED: opencode-widget/Sources/OpencodeWidgetShared/AuthReader.swift] [CITED: opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift] |

**Installation:** No new packages. Do not add a Keychain wrapper dependency.

**Version verification:** Local development tools are available: Xcode 27.0 (build 27A266a), XcodeGen 2.45.4, and Swift 6.4. The project itself declares macOS 14.0 and a SwiftPM macOS 14 target. [CITED: local tool probe] [CITED: opencode-widget/project.yml] [CITED: opencode-widget/Package.swift]

## Architecture Patterns

### System Architecture Diagram

```text
Status-bar popover
       |
       +-- Refresh -> DataFetcher -> per-provider CredentialResolver
       |                  |                 |--> Keychain secret (first)
       |                  |                 `--> legacy auth.json (fallback, read-only)
       |                  +--> provider HTTPS endpoints
       |                  +--> cache / ledger / charts (unchanged)
       |
       +-- SettingsLink -> singleton SwiftUI Settings scene
                              |
                              +--> DisplayPreferences <-> UserDefaults (three Bool values)
                              |         `--> MenuContent layout only
                              |
                              +--> Provider setup coordinator
                              |         -> validate candidate at selected provider
                              |         -> Keychain upsert/remove after validation
                              |
                              `--> Codex availability -> read-only boolean check
                                                   -> Pasteboard: literal `codex login`
```

### Recommended Project Structure

```text
Sources/
├── OpencodeWidgetShared/
│   ├── ProviderDisplayPreferences.swift   # typed non-secret visibility persistence
│   ├── ProviderCredentialStore.swift      # Security generic-password implementation + protocol
│   ├── ProviderCredentialResolver.swift   # Keychain-first, individual legacy fallback
│   └── AuthReader.swift                   # add narrow legacy/Codex availability readers
└── OpencodeWidgetApp/
    ├── ProviderSettingsView.swift         # compact scrollable Providers page and configure rows
    ├── ProviderSetupCoordinator.swift     # validate-before-commit, per-provider generation guard
    ├── OpencodeWidgetApp.swift             # Settings scene, SettingsLink, conditional menu layout
    └── DataFetcher.swift                   # consume independently resolved credentials only
```

### Pattern 1: Native singleton settings presentation
**What:** Keep the current SwiftUI `Settings` scene and put a labelled `SettingsLink` in the footer.

**When to use:** Always for this phase; it satisfies repeated-click singleton/focus behaviour without AppKit window ownership.

**Example:**
```swift
// Adapted from Apple Settings / SettingsLink documentation.
@main
struct OpencodeWidgetApp: App {
    var body: some Scene {
        Settings {
            ProviderSettingsView()
        }
    }
}

// In MenuContent, between Refresh and Quit:
SettingsLink {
    Text("Settings")
}
.buttonStyle(.plain)
```
Source: [CITED: https://developer.apple.com/documentation/swiftui/settings.md] [CITED: https://developer.apple.com/documentation/swiftui/settingslink.md]

### Pattern 2: Typed, presentation-only preferences
**What:** Use one model with three independently named Boolean values, initialized by `object(forKey:) as? Bool ?? true`; inject a UserDefaults suite in tests.

**When to use:** For every card visibility read/write. Do not use `bool(forKey:)` alone because a missing value is indistinguishable from `false`, violating the required default-visible recovery.

**Example:**
```swift
// Values are non-secret. A malformed/missing value recovers to visible.
enum ProviderID: String, CaseIterable { case deepseek, minimax, openAI }

func isCardVisible(_ provider: ProviderID, defaults: UserDefaults) -> Bool {
    defaults.object(forKey: "provider-card-visible.\(provider.rawValue)") as? Bool ?? true
}
```
Source: [CITED: https://developer.apple.com/documentation/foundation/userdefaults.md] [CITED: 05-SPEC.md]

### Pattern 3: Validate, then atomically replace the selected secret
**What:** Retain the existing Keychain value through a candidate validation. On success, replace/add only that provider's generic-password item; on failure, do not write. Maintain a per-provider save generation so an older slow validation cannot overwrite a later request.

**When to use:** DeepSeek and MiniMax Configure/Replace flows only.

**Example:**
```swift
// Run synchronous Security calls off the MainActor; never print candidateKey.
func saveIfCurrent(provider: ProviderID, candidateKey: String, generation: Int) async {
    let isValid = await validator.validate(candidateKey, for: provider)
    guard isValid, generation == saveGeneration[provider] else { return }
    await keychainStore.upsert(candidateKey, for: provider) // add or update, never UserDefaults
}
```
Source: [CITED: https://developer.apple.com/documentation/security/secitemadd(_:_:).md] [CITED: https://developer.apple.com/documentation/security/secitemupdate(_:_:).md] [CITED: 05-SPEC.md]

### Pattern 4: Per-provider Keychain-first credential resolution
**What:** Replace the current `readCredentials` gate with individual resolver calls. Each one returns its own Keychain value when present; otherwise it reads only that provider's legacy JSON value. The resolver has no mutation API for the legacy file.

**When to use:** At the existing provider fetch call sites in `DataFetcher.refreshAll()`.

**Example:**
```swift
let deepSeekKey = await credentials.resolve(.deepseek) // Keychain, then legacy read
let miniMaxKey = await credentials.resolve(.minimax)   // independent path

async let deepSeekBalance: Double? = {
    guard let deepSeekKey else { return nil }
    return await DataFetcher.fetchDeepseekBalance(apiKey: deepSeekKey, session: session)
}()
```
Source: [CITED: 05-SPEC.md] [CITED: opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift]

### Anti-Patterns to Avoid
- **Manual `NSWindow`/`NSWindowController` settings lifecycle:** duplicates the singleton/focus responsibility that `SettingsLink` already owns. [CITED: https://developer.apple.com/documentation/swiftui/settingslink.md]
- **`@AppStorage` alone for recovery semantics:** it is convenient, but a typed preferences facade is needed to distinguish an actual stored Bool from missing/malformed data and default visible. [CITED: 05-SPEC.md]
- **One combined DeepSeek/MiniMax credentials object:** blocks independently configured accounts because the existing reader returns nil if either provider is absent. [CITED: opencode-widget/Sources/OpencodeWidgetShared/AuthReader.swift]
- **Writing a candidate before validation:** a failed candidate would replace a working Keychain secret, contradicting SETTINGS-06. [CITED: 05-SPEC.md]
- **Filtering fetches based on visibility:** turns a presentation preference into a collection/ledger/chart behaviour change. [CITED: 05-SPEC.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Secret encryption/storage | JSON, plist, UserDefaults, or `DataStore` credential vault | Security Keychain Services generic-password items | Keychain is Apple's encrypted secret store; UserDefaults is explicitly unencrypted disk storage. [CITED: https://developer.apple.com/documentation/security/keychain-services.md] [CITED: https://developer.apple.com/documentation/foundation/userdefaults.md] |
| Singleton Settings window | Custom AppKit window registry | SwiftUI `Settings` + `SettingsLink` | Native API opens or orders the current Settings window front. [CITED: https://developer.apple.com/documentation/swiftui/settingslink.md] |
| Keychain replace logic | Delete-then-add sequence | Match by generic-password service/account; update first, add only for item-not-found | Generic password primary identity includes service and account; update preserves the old item until a successful replacement path is selected. [CITED: https://developer.apple.com/documentation/security/ksecclassgenericpassword.md] [CITED: https://developer.apple.com/documentation/security/secitemupdate(_:_:).md] |
| Provider API validation client | New HTTP client or an all-provider refresh | Existing injected `URLSession` and selected provider fetch endpoint | Keeps validation limited to the provider chosen and preserves the test seam. [CITED: opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift] |

**Key insight:** This phase needs small adapters around mature platform services, not new infrastructure. The correctness risk is in maintaining strict boundaries—secret vs. preference and display vs. data path—not in building a settings framework.

## Common Pitfalls

### Pitfall 1: Existing all-or-nothing legacy parsing leaks into the new resolver
**What goes wrong:** A DeepSeek Keychain key plus no MiniMax key produces no DeepSeek refresh because `AuthReader.readCredentials` requires both JSON members.  
**Why it happens:** Current `AuthCredentials` and `refreshAll()` are intentionally coupled to an OpenCode installation. [CITED: opencode-widget/Sources/OpencodeWidgetShared/AuthReader.swift] [CITED: opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift]  
**How to avoid:** Add individual legacy readers and resolve/fetch each provider separately.  
**Warning signs:** A fixture with only one saved Keychain credential yields both balances nil.

### Pitfall 2: Missing/malformed preference reads hide every card
**What goes wrong:** `bool(forKey:)` produces `false` for a missing key, which is the opposite of the required default-visible behaviour.  
**Why it happens:** The primitive Boolean API cannot report whether a correctly typed value existed.  
**How to avoid:** Read `object(forKey:) as? Bool ?? true`, with a fresh injected test suite.  
**Warning signs:** Fresh install, malformed fixture, or legacy suite starts in charts-only mode. [CITED: 05-SPEC.md]

### Pitfall 3: Security calls freeze the menu or setup page
**What goes wrong:** Keychain read/write/remove work can block the main thread.  
**Why it happens:** Apple's `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, and `SecItemDelete` documentation warns that they block. [CITED: https://developer.apple.com/documentation/security/secitemadd(_:_:).md] [CITED: https://developer.apple.com/documentation/security/secitemcopymatching(_:_:).md]  
**How to avoid:** Execute Keychain work on a background/non-MainActor path and marshal only status UI changes back to the main actor.  
**Warning signs:** Typing or toggles stutter during Configure/Remove.

### Pitfall 4: A late validation response overwrites a newer valid key
**What goes wrong:** Candidate A starts validation, candidate B starts later and saves, then A returns success and replaces B.  
**Why it happens:** Separate async validations complete out of order.  
**How to avoid:** Increment a per-provider generation before validation; persist only if the completed generation is still current.  
**Warning signs:** A deterministic delayed-validator test ends with the first value rather than the final requested value. [CITED: 05-SPEC.md]

### Pitfall 5: Visibility accidentally controls the data path
**What goes wrong:** Hiding a card stops its request, ledger snapshot, cache update, or chart series.  
**Why it happens:** A visibility condition is placed around `refreshAll()` or is passed into the fetcher.  
**How to avoid:** Restrict visibility to `MenuContent`'s card/layout branches; keep both refresh entry points and all ledger/chart inputs signature-compatible.  
**Warning signs:** Comparing caches, recorded rows, or chart inputs before/after a visibility change differs. [CITED: 05-SPEC.md]

### Pitfall 6: Secret redaction is only a UI concern
**What goes wrong:** The field masks the key, but the key reaches UserDefaults, `WidgetCache`, test logs, errors, or a copied legacy file.  
**Why it happens:** A settings coordinator serializes a broad state object or interpolates an error with request headers.  
**How to avoid:** Keep candidate strings local to validation and Keychain upsert; model only status/error categories in observable UI state. Never expose a credential through a `CustomStringConvertible`, logger, cache, or error message.  
**Warning signs:** A recursive scan of fixture preferences/cache/ledger contains the test secret. [CITED: 05-SPEC.md]

## Code Examples

Verified patterns from official sources:

### Generic-password identity and read query
```swift
// Service + account identify a generic-password item.
// Request secret data only in the resolver, never for the Settings label.
let query: [CFString: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: service,
    kSecAttrAccount: providerAccount,
    kSecReturnData: true,
    kSecMatchLimit: kSecMatchLimitOne
]
var item: CFTypeRef?
let status = SecItemCopyMatching(query as CFDictionary, &item)
```
Source: [CITED: https://developer.apple.com/documentation/security/secitemcopymatching(_:_:).md] [CITED: https://developer.apple.com/documentation/security/ksecclassgenericpassword.md] [CITED: https://developer.apple.com/documentation/security/ksecattrservice.md] [CITED: https://developer.apple.com/documentation/security/ksecattraccount.md]

### Password replace without a transient plaintext preference
```swift
let match: [CFString: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: service,
    kSecAttrAccount: providerAccount
]
let update: [CFString: Any] = [kSecValueData: Data(candidate.utf8)]
let updateStatus = SecItemUpdate(match as CFDictionary, update as CFDictionary)

if updateStatus == errSecItemNotFound {
    let attributes = match.merging(update) { _, latest in latest }
    guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else { return }
}
```
Source: [CITED: https://developer.apple.com/documentation/security/secitemadd(_:_:).md] [CITED: https://developer.apple.com/documentation/security/secitemupdate(_:_:).md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Empty `Settings` scene and no footer action | `Settings` page activated by `SettingsLink` | This phase | Native singleton settings window; no custom window lifecycle. [CITED: opencode-widget/Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift] [CITED: https://developer.apple.com/documentation/swiftui/settingslink.md] |
| One legacy `auth.json` requiring both provider keys | Independent Keychain-first resolution with per-provider read-only legacy fallback | This phase | DMG users can configure either provider independently; legacy OpenCode users retain their setup. [CITED: 05-SPEC.md] |
| Always-rendered cards | Pure rendering based on persisted preference state | This phase | Users may select any subset, including charts-only, while collection remains unchanged. [CITED: 05-SPEC.md] |

**Deprecated/outdated:**
- Storing an API key in an app preference or cache is not acceptable here; Apple documents UserDefaults as unencrypted and the phase explicitly prohibits non-Keychain secret persistence. [CITED: https://developer.apple.com/documentation/foundation/userdefaults.md] [CITED: 05-SPEC.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A single generic-password Keychain service with stable provider-specific account values is the preferred naming shape. The release contract is service `com.fathur6.opencode-widget.provider-credentials` with `deepseek-api-key` and `minimax-api-key` accounts. [RESOLVED] | Architecture Patterns | Existing released builds could retain stale credentials if identifiers are renamed later; keep these identifiers stable and test with a fresh service namespace. |

## Open Questions (RESOLVED)

1. **What exact Keychain service and account identifiers become the release contract?**
    - **Resolved:** Use `com.fathur6.opencode-widget.provider-credentials` for `kSecAttrService`, `deepseek-api-key` for the DeepSeek `kSecAttrAccount`, and `minimax-api-key` for the MiniMax `kSecAttrAccount`.
    - Rationale: Generic-password identity supports stable service/account pairs; these explicit constants are independent of UI labels and must remain migration-stable after release. [CITED: https://developer.apple.com/documentation/security/ksecclassgenericpassword.md] [CITED: 05-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| macOS Security / `security` CLI | Keychain implementation and manual verification | ✓ | System tool present | — |
| Xcode | macOS app build/test | ✓ | 27.0 (27A266a) | — |
| XcodeGen | Generate production Xcode project | ✓ | 2.45.4 | Existing generated project for investigation only |
| Swift / SwiftPM | XCTest unit suite | ✓ | Swift 6.4; manifest declares Swift tools 6.3 | — |
| Provider account/API key | Live validation UAT | Unknown / user-supplied | — | URLProtocol-based tests; human verifies a real key at phase gate |
| Codex OAuth session | Connected-state UAT | Unknown / user-supplied | — | Missing/malformed fixture verifies Not connected |

**Missing dependencies with no fallback:** None identified for coding and automated tests.

**Missing dependencies with fallback:** Live provider/Codex credentials are not required for automated tests; use fixtures and defer live validation to human verification.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest through SwiftPM test targets |
| Config file | `opencode-widget/Package.swift` |
| Quick run command | `cd opencode-widget && swift test --filter Provider` |
| Full suite command | `cd opencode-widget && swift test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SETTINGS-01 | Footer order and single Settings presentation mechanism | unit + manual UI | `swift test --filter ProviderSettingsTests` | ❌ Wave 0 |
| SETTINGS-02 | Per-provider persistence, malformed recovery, final selection | unit | `swift test --filter ProviderDisplayPreferencesTests` | ❌ Wave 0 |
| SETTINGS-03 | Fixed visible-card order and charts-only layout | unit | `swift test --filter ProviderCardLayoutTests` | ❌ Wave 0 |
| SETTINGS-04 | Same fetch/cache/ledger/chart inputs regardless of visibility | integration-style unit | `swift test --filter ProviderDisplayIsolationTests` | ❌ Wave 0 |
| SETTINGS-05 | Keychain override, legacy fallback, independent removal, legacy untouched | unit with fake store/file fixtures | `swift test --filter ProviderCredentialResolverTests` | ❌ Wave 0 |
| SETTINGS-06 | Per-provider validate-before-save, rollback, redaction, generation ordering | async unit | `swift test --filter ProviderSetupCoordinatorTests` | ❌ Wave 0 |
| SETTINGS-07 | Codex valid/missing/malformed status and exact copy command without process | unit | `swift test --filter CodexConnectionStatusTests` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `cd opencode-widget && swift test --filter Provider`
- **Per wave merge:** `cd opencode-widget && swift test`
- **Phase gate:** Full suite green plus manual native Settings/Keychain/live credential checks before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift` — SETTINGS-02 and pure layout coverage for SETTINGS-03.
- [ ] `Tests/OpencodeWidgetSharedTests/ProviderCredentialResolverTests.swift` — SETTINGS-05 with in-memory secret-store fake and legacy fixture checksum.
- [ ] `Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift` — SETTINGS-01, SETTINGS-04, SETTINGS-06, and SETTINGS-07 coordinator/status tests using injected validator/pasteboard/process-free doubles.
- [ ] Existing test infrastructure otherwise suffices: `Package.swift` already defines shared and app XCTest targets, and `DataFetcherTests` already supplies an injected `URLProtocol` pattern. [CITED: opencode-widget/Package.swift] [CITED: opencode-widget/Tests/OpencodeWidgetAppTests/DataFetcherTests.swift]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | Only test connection status for existing Codex OAuth; never initiate Codex authentication in-app. [CITED: 05-SPEC.md] |
| V3 Session Management | Yes | Read existing `~/.codex/auth.json` only through a boolean availability helper for Settings; never render/log/cache its token. [CITED: 05-SPEC.md] |
| V4 Access Control | Yes | Keep Keychain item scope app-owned; do not add an access group unless a future sharing requirement explicitly needs it. Apple's docs describe app entitlement-based access. [CITED: https://developer.apple.com/documentation/security/secitemadd(_:_:).md] |
| V5 Input Validation | Yes | Reject empty candidate values locally; validate each nonempty candidate only against the selected provider's HTTPS endpoint; represent errors without echoing a secret. [CITED: 05-SPEC.md] |
| V6 Cryptography | Yes | Use Keychain Services, not custom encryption or preference storage. [CITED: https://developer.apple.com/documentation/security/keychain-services.md] |

### Known Threat Patterns for SwiftUI/Keychain settings

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Secret disclosure through UI, logs, cache, or tests | Information Disclosure | Keychain-only persistence; status-only UI; redacted error types; artifact scan using synthetic secrets. [CITED: 05-SPEC.md] |
| A failed or stale validation replaces a working key | Tampering | Validate-before-upsert and per-provider generation guard. [CITED: 05-SPEC.md] |
| Accidental write/delete of OpenCode legacy credentials | Tampering | Resolver exposes legacy read only; fixture checksum/content test asserts file unchanged. [CITED: 05-SPEC.md] |
| Settings action runs shell authentication | Elevation of Privilege | Copy exact literal `codex login` to pasteboard only; do not import/use `Process` for this flow. [CITED: 05-SPEC.md] |
| UI hang from blocking keychain calls | Denial of Service | Run Security operations away from `MainActor`. [CITED: https://developer.apple.com/documentation/security/secitemcopymatching(_:_:).md] |

## Sources

### Primary (HIGH confidence)
- None. The research-plan seam selected Context7, but Context7 CLI/MCP was unavailable in this session.

### Secondary (MEDIUM confidence)
- None. The confidence seam classified the available `webfetch` provider as LOW even for direct Apple documentation.

### Tertiary (LOW confidence)
- Apple Developer Documentation — [Settings](https://developer.apple.com/documentation/swiftui/settings.md), [SettingsLink](https://developer.apple.com/documentation/swiftui/settingslink.md), and [openSettings](https://developer.apple.com/documentation/swiftui/environmentvalues/opensettings.md) — native Settings scene and singleton/fronting behaviour.
- Apple Developer Documentation — [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults.md) — persistence, registration defaults, thread safety, and non-secret storage rule.
- Apple Developer Documentation — [Keychain Services](https://developer.apple.com/documentation/security/keychain-services.md), [SecItemAdd](https://developer.apple.com/documentation/security/secitemadd(_:_:).md), [SecItemCopyMatching](https://developer.apple.com/documentation/security/secitemcopymatching(_:_:).md), [SecItemUpdate](https://developer.apple.com/documentation/security/secitemupdate(_:_:).md), and [SecItemDelete](https://developer.apple.com/documentation/security/secitemdelete(_:).md) — system secret store and item lifecycle.
- Repository sources: `05-SPEC.md`, `05-CONTEXT.md`, `DataFetcher.swift`, `AuthReader.swift`, `DataStore.swift`, `OpencodeWidgetApp.swift`, `Package.swift`, and existing XCTest files — phase-specific contracts and integration seams.

## Metadata

**Confidence breakdown:**
- Standard stack: LOW — direct Apple sources and current code were checked, but the required source-confidence seam rated the available fetch provider LOW.
- Architecture: LOW — based on exact phase constraints plus verified existing code; no Context7/source cross-check was available.
- Pitfalls: LOW — derived from direct code-path inspection and phase acceptance edges; external search was unavailable.

**Research date:** 2026-09-17  
**Valid until:** 2026-09-24 — Settings/Keychain APIs are stable, but research confidence is constrained by provider availability.
