# Phase 05: Settings: Provider Display Preferences - Pattern Map

**Mapped:** 2026-09-17  
**Files analyzed:** 12 likely new/modified files  
**Analogs found:** 9 / 12 (three storage/resolution seams have no direct implementation analog)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `Sources/OpencodeWidgetShared/ProviderDisplayPreferences.swift` | store / utility | transform | `DataStore.swift` | partial — persistent boundary only |
| `Sources/OpencodeWidgetShared/ProviderCredentialStore.swift` | service | CRUD | none | no direct analog |
| `Sources/OpencodeWidgetShared/ProviderCredentialResolver.swift` | service | request-response | `AuthReader.swift` | role-match |
| `Sources/OpencodeWidgetShared/AuthReader.swift` | utility | file-I/O | itself | exact modification seam |
| `Sources/OpencodeWidgetApp/ProviderSettingsView.swift` | component | event-driven | `Views/OnboardingView.swift` | partial — form controls only |
| `Sources/OpencodeWidgetApp/ProviderSetupCoordinator.swift` | service / controller | request-response | `ViewModels/OnboardingViewModel.swift` | partial — async state only |
| `Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift` | app composition / component | event-driven | itself | exact modification seam |
| `Sources/OpencodeWidgetApp/DataFetcher.swift` | service | request-response | itself | exact modification seam |
| `Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift` | test | transform | `DataStoreTests.swift` | role-match |
| `Tests/OpencodeWidgetSharedTests/ProviderCredentialResolverTests.swift` | test | file-I/O / request-response | `AuthReaderTests.swift` | role-match |
| `Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift` | test | event-driven / request-response | `MenuContentTests.swift`, `OnboardingViewModelTests.swift` | role-match |
| `Tests/OpencodeWidgetAppTests/DataFetcherTests.swift` | test (modify) | request-response | itself | exact modification seam |

`project.yml` and `Package.swift` should not need changes: both targets include their entire `Sources/...` and `Tests/...` directories (`project.yml:11-15`, `Package.swift:10-46`). Do not create a target or enumerate individual files.

## Pattern Assignments

### `Sources/OpencodeWidgetShared/ProviderDisplayPreferences.swift` (store/utility, transform)

**Closest analog:** `Sources/OpencodeWidgetShared/DataStore.swift`

Use a public typed facade with injectable persistence, parallel to `DataStore`'s explicit defaults and injectable path/suite parameters. Unlike `DataStore`, this stores only non-secret Booleans. `object(forKey:) as? Bool ?? true` is required so missing, malformed, and legacy values recover to visible.

**Public static API and parameter injection** (`DataStore.swift:3-7,29-43`):
```swift
public enum DataStore {
    public static let defaultSuiteName = "group.com.opencode.widget"
    public static let defaultFileName = "widget-data.json"

    public static func save(cache: WidgetCache, suiteName: String = defaultSuiteName, fileName: String = defaultFileName) {
        guard let url = sharedContainerURL(suiteName: suiteName, fileName: fileName) else { return }
        // ... encode only WidgetCache ...
    }
}
```

**Required adaptation:** define one `ProviderID: String, CaseIterable, Sendable` in Shared with fixed ordering `.deepseek, .minimax, .openAI`; expose explicit `isCardVisible`/`setCardVisible` APIs (or observable properties) backed by an injected `UserDefaults`. Keep a pure ordered-card/layout function beside this model so `MenuContent` consumes presentation state only. Do **not** use `DataStore` or `WidgetCache` for preferences.

---

### `Sources/OpencodeWidgetShared/ProviderCredentialStore.swift` (service, CRUD)

**Analog:** none in the current codebase; `grep` found no `Security`, `SecItem*`, or `kSec*` implementation.

Implement a narrow injectable protocol plus production generic-password Keychain adapter. Copy the project's dependency-injection style, not its file persistence: production calls must be non-MainActor/background; test fakes stay in memory.

**Do not copy this cache persistence path** (`DataStore.swift:29-35`):
```swift
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
encoder.dateEncodingStrategy = .iso8601
guard let data = try? encoder.encode(cache) else { return }
try? data.write(to: url, options: .atomic)
```

It is explicitly for `WidgetCache`; API keys must never enter it. Use the Security-framework generic-password match/update/add flow from `05-RESEARCH.md:276-305`, with stable service and provider-account constants. `upsert`, `read`, and `remove` must operate on one provider only and return status/error categories that do not include the secret.

---

### `Sources/OpencodeWidgetShared/ProviderCredentialResolver.swift` (service, request-response)

**Analog:** `Sources/OpencodeWidgetShared/AuthReader.swift`

Use the existing small, typed, non-throwing file-reader convention, but resolve exactly one provider at a time: Keychain first, then its matching legacy value. The resolver must have no legacy write API.

**Legacy JSON read/error boundary** (`AuthReader.swift:23-39`):
```swift
public static func readCredentials(authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json") -> AuthCredentials? {
    let url = URL(fileURLWithPath: authPath)
    guard let data = try? Data(contentsOf: url),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }

    guard let deepseekAuth = json["deepseek"] as? [String: Any],
          let deepseekKey = deepseekAuth["key"] as? String,
          let minimaxAuth = json["minimax"] as? [String: Any],
          let minimaxKey = minimaxAuth["key"] as? String else {
        return nil
    }
    return AuthCredentials(deepseekKey: deepseekKey, minimaxKey: minimaxKey)
}
```

**Required adaptation:** move/add narrow `readLegacyKey(for:authPath:)` functionality in `AuthReader`, retaining `try?`/`nil` failure semantics but avoiding the current all-or-nothing gate. The resolver calls store read first, then that narrow reader only when the store has no value. Preserve the legacy bytes unchanged.

---

### `Sources/OpencodeWidgetShared/AuthReader.swift` (utility, file-I/O)

**Analog:** existing file; extend, do not replace the OpenAI contract.

**Sensitive value is returned only to the network caller and never logged** (`AuthReader.swift:41-57`):
```swift
/// Reads the OAuth token produced by `codex login`. The token is returned
/// only to the caller and is never logged or persisted by this module.
public static func readOpenAICredentials(authPath: String = "\(NSHomeDirectory())/.codex/auth.json") -> OpenAIAuthCredentials? {
    let url = URL(fileURLWithPath: authPath)
    guard let data = try? Data(contentsOf: url),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tokens = json["tokens"] as? [String: Any],
          let accessToken = tokens["access_token"] as? String,
          !accessToken.isEmpty else { return nil }
    return OpenAIAuthCredentials(accessToken: accessToken, accountID: tokens["account_id"] as? String)
}
```

Add a status-only Codex helper that evaluates the same valid/nonempty token shape but returns a Boolean; it must never expose the token to `ProviderSettingsView`. Add individual legacy DeepSeek/MiniMax readers; leave `readCredentials` intact only if other targets still consume it.

---

### `Sources/OpencodeWidgetApp/ProviderSettingsView.swift` (component, event-driven)

**Closest analog:** `Sources/OpencodeUsageTrackerApp/Views/OnboardingView.swift`

Copy the local `@State` initialization, `SecureField`, standard control styling, disabled controls, and progress affordance. Do **not** copy the two-provider, all-at-once onboarding flow; this phase has independent expandable provider rows.

**View-owned observable state and progressive secure input** (`OnboardingView.swift:3-10,27-42`):
```swift
struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel

    init(authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json", onComplete: @escaping () -> Void) {
        self._viewModel = State(initialValue: OnboardingViewModel(authPath: authPath))
        self.onComplete = onComplete
    }

    // ...
    SecureField("sk-...", text: $viewModel.deepseekKey)
        .textFieldStyle(.roundedBorder)
}
```

**Async action state** (`OnboardingView.swift:46-65`):
```swift
if !viewModel.statusMessage.isEmpty {
    Text(viewModel.statusMessage)
        .foregroundColor(viewModel.statusMessage.contains("Error") ? DesignSystem.Color.critical : DesignSystem.Color.safe)
}
Button(action: { Task { await viewModel.verifyAndSave(onComplete: onComplete) } }) {
    if viewModel.isLoading { ProgressView().scaleEffect(0.8) }
    else { Text("Get Started").frame(maxWidth: 200) }
}
.disabled(viewModel.deepseekKey.isEmpty || viewModel.minimaxKey.isEmpty || viewModel.isLoading)
```

**Required adaptation:** use a `ScrollView` with a bounded ~440px `frame(minWidth:)`, one `Providers` page, and three fixed-order rows. Each row has its visibility toggle and status; only DeepSeek/MiniMax exposes Configure/Remove. The OpenAI row has status plus pasteboard copy of literal `codex login`, never a key field. Use standard SwiftUI controls; retain `MenuContent`'s monochrome card colours only as visual context.

---

### `Sources/OpencodeWidgetApp/ProviderSetupCoordinator.swift` (service/controller, request-response)

**Closest analog:** `Sources/OpencodeUsageTrackerApp/ViewModels/OnboardingViewModel.swift`

Use an `@MainActor @Observable` coordinator for UI-visible input/state and injectable async dependencies. Validate one selected provider at a time with the existing `DataFetcher` endpoint functions, then call the Keychain store only after validation succeeds.

**Observable, MainActor UI state** (`OnboardingViewModel.swift:7-24`):
```swift
@MainActor
@Observable
final class OnboardingViewModel {
    var deepseekKey = ""
    var minimaxKey = ""
    var statusMessage = ""
    var isLoading = false

    func verifyAndSave(session: URLSession = .shared, onComplete: @escaping () -> Void) async {
        guard !deepseekKey.isEmpty, !minimaxKey.isEmpty else { return }
        isLoading = true
        statusMessage = "Verifying..."
    }
}
```

**Existing selected-provider validation endpoint seam** (`DataFetcher.swift:27-40`):
```swift
static func fetchDeepseekBalance(apiKey: String, session: URLSession = .shared) async -> Double? {
    var request = URLRequest(url: deepseekBalanceURL)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 10
    guard let data = try? await session.data(for: request).0,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let infos = json["balance_infos"] as? [[String: Any]],
          let first = infos.first,
          let balanceStr = first["total_balance"] as? String,
          let balance = Double(balanceStr) else { return nil }
    return balance
}
```

**Do not copy this legacy write** (`OnboardingViewModel.swift:42-50`):
```swift
let authDict: [String: [String: String]] = [
    "deepseek": ["key": deepseekKey],
    "minimax": ["key": minimaxKey],
]
// ... JSONSerialization ... data.write(to: url)
```

The coordinator needs per-provider save generations: increment before validation and upsert only when the success generation still matches. Publish redacted state/error categories, not `Error.localizedDescription` if it could reveal request headers or a secret. Send Security calls away from the main actor; update observable UI state on it.

---

### `Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift` (app composition/component, event-driven)

**Analog:** existing app and menu composition.

**Scene and native/AppKit boundary** (`OpencodeWidgetApp.swift:41-47,97-110`):
```swift
@main
struct OpencodeWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

private func buildMenu() {
    let menu = NSMenu()
    let item = NSMenuItem()
    let host = NSHostingView(rootView: MenuContent())
    host.frame.size = host.fittingSize
    item.view = host
    menu.addItem(item)
    statusItem.menu = menu
}
```

**Footer order to modify** (`OpencodeWidgetApp.swift:269-280`):
```swift
VStack(spacing: 2) {
    Button("Refresh") { refreshData() }
        .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 4).keyboardShortcut("r")
    Divider()
    Button("Quit") { NSApp.terminate(nil) }
        .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 4).keyboardShortcut("q")
}
```

Replace `EmptyView()` with the injected `ProviderSettingsView`. Put a labelled `SettingsLink` between Refresh and Quit; do not build a custom `NSWindowController`. Inject the same display-preferences instance into Settings and `MenuContent`. In `MenuContent.body`, condition only the balance-card HStack and OpenAI card, preserving card order; leave chart range/filtering, charts, footer refresh, and all data calls outside visibility branches.

---

### `Sources/OpencodeWidgetApp/DataFetcher.swift` (service, request-response)

**Analog:** existing independent async `refreshAll` orchestration.

**Current all-or-nothing gate — replace it, do not propagate it** (`DataFetcher.swift:126-169`):
```swift
let usage = queryUsageFromDB(dbPath: dbPath)
let previousCache = DataStore.load(suiteName: cacheSuiteName, fileName: cacheFileName)
let fetchedOpenAIQuotaTask = Task {
    await openAIQuotaFetcher(openAIAuthPath, session, openAIUsageURL)
}

guard let creds = AuthReader.readCredentials(authPath: authPath) else {
    // fallback cache result
}

let dk = creds.deepseekKey
let mk = creds.minimaxKey
async let dsBalance = fetchDeepseekBalance(apiKey: dk, session: session)
async let mmCredit = fetchMiniMaxCredit(apiKey: mk, session: session)
async let mmUsage = fetchMiniMaxUsage(apiKey: mk, session: session)
```

**Keep current stale-cache/error behavior** (`DataFetcher.swift:171-192`):
```swift
let minimaxCreditVal: Double?
if let credit = minimaxCredit {
    minimaxCreditVal = credit
} else {
    minimaxCreditVal = readSavedMiniMaxCredit(suiteName: savedBalanceSuiteName)
}
let minimaxBalance = minimaxCreditVal ?? minimaxUsage.map { Double($0.remainingPrompts) }
    ?? readSavedMiniMaxBalance(suiteName: savedBalanceSuiteName)
```

Accept an injectable per-provider resolver (with a production default). Independently resolve/fetch DeepSeek and MiniMax; a missing key must only suppress that provider's network calls. Do not add display preferences to this signature or any resulting `WidgetCache` data path. Keep OpenAI's existing separately launched task and cached-quota merge intact.

---

### `Tests/OpencodeWidgetSharedTests/ProviderDisplayPreferencesTests.swift` (test, transform)

**Closest analog:** `Tests/OpencodeWidgetSharedTests/DataStoreTests.swift`

Copy per-test isolation and round-trip assertions, but create a fresh `UserDefaults(suiteName:)` suite and remove its persistent domain in teardown. Test all default-visible recovery cases (missing, non-Bool/malformed, legacy), independent writes, same-value writes, and final rapid selection. Exercise the pure layout against all visibility combinations and assert `deepseek, minimax, openAI` order plus empty charts-only output.

**Fixture lifecycle and round-trip shape** (`DataStoreTests.swift:14-30,42-46`):
```swift
override func setUp() {
    super.setUp()
    tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: false)
}
override func tearDown() {
    try? FileManager.default.removeItem(at: tempDir)
    tempDir = nil
    super.tearDown()
}
```

---

### `Tests/OpencodeWidgetSharedTests/ProviderCredentialResolverTests.swift` (test, file-I/O/request-response)

**Closest analog:** `Tests/OpencodeWidgetAppTests/AuthReaderTests.swift`

Use temporary legacy JSON fixtures and an in-memory fake credential-store protocol—not the real user Keychain. Assert Keychain precedence, individual fallback, removal-to-fallback, and an exact before/after `Data` equality check of the legacy file. Include missing/invalid JSON and ensure a synthetic secret never appears in test preference/cache artifacts.

**Existing temporary auth fixture convention** (`AuthReaderTests.swift:5-19,22-35`):
```swift
let tempDir = FileManager.default.temporaryDirectory
var tempAuthPath: String!

override func setUp() {
    super.setUp()
    tempAuthPath = tempDir.appendingPathComponent("test-auth-\(UUID().uuidString).json").path
}

let creds = AuthReader.readCredentials(authPath: tempAuthPath)
XCTAssertEqual(creds?.deepseekKey, "ds-key-123")
```

---

### `Tests/OpencodeWidgetAppTests/ProviderSettingsTests.swift` (test, event-driven/request-response)

**Closest analogs:** `MenuContentTests.swift` and `OnboardingViewModelTests.swift`

Make view-adjacent requirements pure/testable helpers: footer action identifiers/order, visible-card layout, Codex Boolean status, and pasteboard writer injection. For setup coordination, inject fake validator, fake credential store, and pasteboard writer; test valid independent save, failed validation retaining prior secret, generation ordering, exact copied `codex login`, and no process dependency. Mark UI-state tests `@MainActor`.

**MainActor pure-view helper tests** (`MenuContentTests.swift:5-18`):
```swift
@MainActor
final class MenuContentTests: XCTestCase {
    func testDualRowsAreIndependentAndFiveHourComesFirst() {
        let rows = MenuContent.quotaRows(quota)
        XCTAssertEqual(rows.map(\.label), ["5h", "Weekly"])
    }
}
```

**Injected session + observable-state expectation** (`OnboardingViewModelTests.swift:42-60`):
```swift
let config = URLSessionConfiguration.ephemeral
config.protocolClasses = [MockURLProtocol.self]
let session = URLSession(configuration: config)

await vm.verifyAndSave(session: session, onComplete: { called = true })
XCTAssertTrue(called)
XCTAssertFalse(vm.isLoading)
```

---

### `Tests/OpencodeWidgetAppTests/DataFetcherTests.swift` (test modification, request-response)

**Analog:** existing injected paths, sessions, and fetcher closure.

Add resolver injection to the existing test calls rather than depending on the host Keychain. Prove a DeepSeek-only resolved key triggers only its request and a MiniMax-only key triggers its requests; then compare cache/ledger/chart inputs under every display-preference value to confirm visibility is absent from `refreshAll`.

**Dependency injection and URLProtocol session pattern** (`DataFetcherTests.swift:250-276`):
```swift
let config = URLSessionConfiguration.ephemeral
config.protocolClasses = [MockURLProtocol.self]
let session = URLSession(configuration: config)

let cache = await DataFetcher.refreshAll(
    dbPath: tempDBPath,
    authPath: tempAuthPath,
    session: session,
    openAIAuthPath: tempAuthPath,
    cacheSuiteName: tempCachePath,
    savedBalanceSuiteName: "fixture-\(UUID().uuidString)",
    openAIQuotaFetcher: { _, _, _ in nil }
)
```

## Shared Patterns

### Presentation state is isolated from collection
**Sources:** `OpencodeWidgetApp.swift:181-279`; `DataFetcher.swift:126-192`  
**Apply to:** `ProviderDisplayPreferences`, `ProviderSettingsView`, `MenuContent`, `DataFetcher`.

`MenuContent` currently derives chart buckets and snapshots before rendering cards (`OpencodeWidgetApp.swift:181-187`) and renders charts/footer independently (`256-279`). Preserve that split: preferences may choose card branches only; they must never reach fetcher, `DataStore`, ledger, history, or chart inputs.

### Credential and token safety
**Sources:** `AuthReader.swift:41-57`; `OpenAIQuotaFetcher.swift:60-95`; `DataStore.swift:29-43`  
**Apply to:** resolver, store, setup coordinator, Settings UI, tests.

The existing OAuth path sends a token only as an Authorization header and collapses failures to `nil`:
```swift
guard let (data, response) = try? await session.data(for: request),
      let httpResponse = response as? HTTPURLResponse,
      (200..<300).contains(httpResponse.statusCode) else {
    return nil
}
```
Follow the same non-disclosing failure boundary. Never put a credential/token in an interpolated status string, `WidgetCache`, `DataStore`, UserDefaults, logs, or the legacy auth file.

### Async UI and network testing
**Sources:** `DataFetcherTests.swift:6-39,78-116`; `OnboardingViewModelTests.swift:5-21`  
**Apply to:** provider validation, coordinator state, resolver integration.

Use `URLProtocol` injection for endpoint validation and fake protocol implementations for Keychain/pasteboard. Test observable UI state on `@MainActor`; do not use real network, real Keychain, or process/Terminal invocation.

### Error semantics
**Sources:** `DataFetcher.swift:18-24,32-40,48-57`; `OpenAIQuotaFetcher.swift:87-95`  
**Apply to:** resolver and validation coordinator.

Existing app services return optionals for expected transport/decode failures instead of exposing details. Map them to stable UI states such as validation failed / unavailable; retain a working Keychain entry on failure and do not reveal response bodies or secret-bearing errors.

## No Analog Found

| File | Role | Data Flow | Planner direction |
|---|---|---|---|
| `Sources/OpencodeWidgetShared/ProviderCredentialStore.swift` | service | CRUD | No existing Security/Keychain code. Use the generic-password `SecItemCopyMatching` / update-then-add pattern in `05-RESEARCH.md:276-305`, behind an injectable protocol. |
| `Sources/OpencodeWidgetShared/ProviderDisplayPreferences.swift` | store / utility | transform | No typed display-preference facade exists. Use `object(forKey:) as? Bool ?? true` from `05-RESEARCH.md:167-181`; preserve `DataStore` only as the separation boundary. |
| `Sources/OpencodeWidgetShared/ProviderCredentialResolver.swift` | service | request-response | No per-provider Keychain-first resolver exists. Compose the new store with narrow read-only `AuthReader` legacy readers; never reuse the all-provider `AuthCredentials` gate. |

## Metadata

**Analog search scope:** `opencode-widget/Sources`, `opencode-widget/Tests`, `Package.swift`, `project.yml`  
**Files scanned:** 16 source/test/config files; targeted symbol searches found no current Keychain, SettingsLink, or pasteboard implementation.  
**Pattern extraction date:** 2026-09-17
