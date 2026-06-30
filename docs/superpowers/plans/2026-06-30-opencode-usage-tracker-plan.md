# Opencode Usage Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone macOS app that shows DeepSeek balance, MiniMax per-model usage, and historical token/cost from the local Opencode database.

**Architecture:** New `OpencodeUsageTrackerApp` executable target in the existing SwiftPM package, using MVVM with `@Observable`, reusing `OpencodeWidgetShared` for models/DataStore, and co-existing with the existing widget and menu bar app.

**Tech Stack:** Swift 6.3, SwiftPM, SwiftUI, macOS 14+, SQLite3 (system), UserNotifications

**Auth source:** `~/.local/share/opencode/auth.json` (read by existing `AuthReader`)

---

## Global Constraints

- macOS 14.0+ with `@Observable`
- Swift tools version 6.3
- Minimum window size: 300x400, default: 420x600
- Auth read from `~/.local/share/opencode/auth.json` (existing `AuthReader`)
- Read-only access to `~/.local/share/opencode/opencode.db`
- Auto-refresh interval: 15 minutes (default)
- Design tokens from minimax-usage-checker compact design system (copied below)

---

## File Structure

### New files in `Sources/OpencodeUsageTrackerApp/`:
```
├── App.swift                                 @main entry point
├── DesignSystem/
│   ├── DesignTokens.swift                    Colors, spacing, typography
│   └── UsageStatus.swift                     Safe/Warning/Critical states
├── Services/
│   ├── DeepSeekAPIService.swift              Fetch /user/balance
│   ├── MiniMaxAPIService.swift               Fetch /coding_plan/remains (per-model)
│   ├── DatabaseService.swift                 Query opencode.db per model+provider
│   └── NotificationManager.swift             Threshold alerts (85%, 95%)
├── ViewModels/
│   └── UsageViewModel.swift                  @Observable: state, auto-refresh, snapshots
├── Views/
│   ├── MainView.swift                        Tab container
│   ├── DashboardView.swift                   Stat cards + trend chart
│   ├── UsageView.swift                       Per-model breakdown
│   ├── HistoryView.swift                     Historical snapshots
│   └── OnboardingView.swift                  API key entry + validation
└── Components/
    ├── StatCard.swift
    ├── ProgressBar.swift
    ├── ModelCard.swift
    ├── TimelineChart.swift
    ├── StatusIndicator.swift
    ├── EmptyStateView.swift
    ├── ErrorStateView.swift
    └── LoadingView.swift
```

### Modified files:
- `Package.swift` — add `OpencodeUsageTrackerApp` target
- `Sources/OpencodeWidgetShared/Models.swift` — add `MiniMaxModelRemain`, `MiniMaxCodingPlanResponse`, `ModelUsageRow`

### New test files in `Tests/OpencodeUsageTrackerAppTests/`:
- `DeepSeekAPIServiceTests.swift`
- `MiniMaxAPIServiceTests.swift`
- `DatabaseServiceTests.swift`
- `NotificationManagerTests.swift`
- `UsageViewModelTests.swift`
- `DesignTokensTests.swift`

---

### Task 1: Package setup + shared models extension

**Files:**
- Modify: `Package.swift` (add target)
- Modify: `Sources/OpencodeWidgetShared/Models.swift` (add models)
- Test: `Tests/OpencodeWidgetSharedTests/ModelsTests.swift` (add tests)

**Interfaces:**
- Consumes: existing `WidgetCache`, `ProviderBalance`, `MiniMaxUsage`, `DailyUsageRow`, `DataStore`
- Produces: `MiniMaxModelRemain`, `MiniMaxCodingPlanResponse`, `ModelUsageRow`

- [ ] **Step 1: Add OpencodeUsageTrackerApp target to Package.swift**

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "OpencodeWidgetApp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "OpencodeWidgetShared"
        ),
        .executableTarget(
            name: "OpencodeWidgetApp",
            dependencies: ["OpencodeWidgetShared"],
            resources: [.copy("Resources")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(
            name: "OpencodeWidget",
            dependencies: ["OpencodeWidgetShared"]
        ),
        .executableTarget(
            name: "OpencodeUsageTrackerApp",
            dependencies: ["OpencodeWidgetShared"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "OpencodeWidgetSharedTests",
            dependencies: ["OpencodeWidgetShared"]
        ),
        .testTarget(
            name: "OpencodeWidgetAppTests",
            dependencies: ["OpencodeWidgetApp"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "OpencodeWidgetTests",
            dependencies: ["OpencodeWidget"]
        ),
        .testTarget(
            name: "OpencodeUsageTrackerAppTests",
            dependencies: ["OpencodeUsageTrackerApp"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
    ]
)
```

- [ ] **Step 2: Add MiniMax model types to Models.swift**

Add before the `WidgetCache` struct:

```swift
public struct MiniMaxModelRemain: Codable, Identifiable, Equatable {
    public var id: String { modelName }
    public let modelName: String
    public let currentIntervalTotalCount: Int
    public let currentIntervalRemainingCount: Int
    public let startTime: Int64
    public let endTime: Int64
    public let remainsTime: Int64

    public init(modelName: String, currentIntervalTotalCount: Int, currentIntervalRemainingCount: Int, startTime: Int64, endTime: Int64, remainsTime: Int64) {
        self.modelName = modelName
        self.currentIntervalTotalCount = currentIntervalTotalCount
        self.currentIntervalRemainingCount = currentIntervalRemainingCount
        self.startTime = startTime
        self.endTime = endTime
        self.remainsTime = remainsTime
    }

    public var usagePercentage: Double {
        guard currentIntervalTotalCount > 0 else { return 0 }
        return Double(currentIntervalTotalCount - currentIntervalRemainingCount) / Double(currentIntervalTotalCount)
    }
}

public struct MiniMaxCodingPlanResponse: Codable {
    public let modelRemains: [MiniMaxModelRemain]
    public let baseResp: MiniMaxBaseResp?

    public init(modelRemains: [MiniMaxModelRemain], baseResp: MiniMaxBaseResp?) {
        self.modelRemains = modelRemains
        self.baseResp = baseResp
    }
}

public struct MiniMaxBaseResp: Codable {
    public let statusCode: Int
    public let statusMsg: String?
}

public struct ModelUsageRow: Codable, Identifiable, Equatable {
    public var id: String { "\(date)-\(provider)-\(modelId)" }
    public let date: String
    public let provider: String
    public let modelId: String
    public let tokens: Int
    public let cost: Double

    public init(date: String, provider: String, modelId: String, tokens: Int, cost: Double) {
        self.date = date
        self.provider = provider
        self.modelId = modelId
        self.tokens = tokens
        self.cost = cost
    }
}
```

- [ ] **Step 3: Add tests for new models**

```swift
// In Tests/OpencodeWidgetSharedTests/ModelsTests.swift

func testMiniMaxModelRemainUsagePercentage() {
    let remain = MiniMaxModelRemain(
        modelName: "test-model",
        currentIntervalTotalCount: 200,
        currentIntervalRemainingCount: 50,
        startTime: 0, endTime: 0, remainsTime: 0
    )
    XCTAssertEqual(remain.usagePercentage, 0.75, accuracy: 0.001)
}

func testMiniMaxModelRemainZeroTotal() {
    let remain = MiniMaxModelRemain(
        modelName: "test-model",
        currentIntervalTotalCount: 0,
        currentIntervalRemainingCount: 0,
        startTime: 0, endTime: 0, remainsTime: 0
    )
    XCTAssertEqual(remain.usagePercentage, 0)
}

func testMiniMaxModelRemainFullUsage() {
    let remain = MiniMaxModelRemain(
        modelName: "test-model",
        currentIntervalTotalCount: 100,
        currentIntervalRemainingCount: 0,
        startTime: 0, endTime: 0, remainsTime: 0
    )
    XCTAssertEqual(remain.usagePercentage, 1.0)
}

func testModelUsageRowId() {
    let row = ModelUsageRow(date: "2026-06-30", provider: "deepseek", modelId: "deepseek-v4-flash", tokens: 100, cost: 1.0)
    XCTAssertEqual(row.id, "2026-06-30-deepseek-deepseek-v4-flash")
}

func testModelUsageRowEquality() {
    let a = ModelUsageRow(date: "2026-06-30", provider: "deepseek", modelId: "v4", tokens: 100, cost: 1.0)
    let b = ModelUsageRow(date: "2026-06-30", provider: "deepseek", modelId: "v4", tokens: 100, cost: 1.0)
    let c = ModelUsageRow(date: "2026-06-30", provider: "deepseek", modelId: "v4", tokens: 200, cost: 2.0)
    XCTAssertEqual(a, b)
    XCTAssertNotEqual(a, c)
}
```

- [ ] **Step 4: Run unit tests to verify they pass**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeWidgetSharedTests 2>&1`
Expected: Tests pass, or target not found yet (will compile after Package.swift update)

- [ ] **Step 5: Commit**

```bash
git -C /Users/aman/Documents/opencode-plugin add opencode-widget/Package.swift opencode-widget/Sources/OpencodeWidgetShared/Models.swift opencode-widget/Tests/OpencodeWidgetSharedTests/ModelsTests.swift
git -C /Users/aman/Documents/opencode-plugin commit -m "feat: add OpencodeUsageTrackerApp target and shared models"
```

---

### Task 2: DesignSystem tokens + UsageStatus

**Files:**
- Create: `Sources/OpencodeUsageTrackerApp/DesignSystem/DesignTokens.swift`
- Create: `Sources/OpencodeUsageTrackerApp/DesignSystem/UsageStatus.swift`
- Test: `Tests/OpencodeUsageTrackerAppTests/DesignTokensTests.swift`

**Interfaces:**
- Produces: `DesignSystem` enums/structs for colors, spacing, typography; `UsageStatus` enum with threshold logic

- [ ] **Step 1: Write DesignTokens.swift**

```swift
import SwiftUI

public enum DesignSystem {
    public enum Typography {
        public static let displayLarge: CGFloat = 24
        public static let displayMedium: CGFloat = 18
        public static let headingLarge: CGFloat = 16
        public static let headingMedium: CGFloat = 14
        public static let bodyLarge: CGFloat = 13
        public static let bodyMedium: CGFloat = 12
        public static let caption: CGFloat = 11
        public static let captionSmall: CGFloat = 10
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Radius {
        public static let sm: CGFloat = 4
        public static let md: CGFloat = 6
        public static let lg: CGFloat = 10
        public static let xl: CGFloat = 16
        public static let full: CGFloat = 9999
    }

    public enum Color {
        public static let safe = SwiftUI.Color.green
        public static let warning = SwiftUI.Color.orange
        public static let critical = SwiftUI.Color.red
        public static let deepseekAccent = SwiftUI.Color.blue
        public static let minimaxAccent = SwiftUI.Color.green
    }
}
```

- [ ] **Step 2: Write UsageStatus.swift**

```swift
import Foundation

public enum UsageStatus: Comparable {
    case safe
    case warning
    case critical

    public init(usedPercentage: Double) {
        switch usedPercentage {
        case 0.0..<0.7:
            self = .safe
        case 0.7..<0.9:
            self = .warning
        default:
            self = .critical
        }
    }

    public var label: String {
        switch self {
        case .safe: return "Safe"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}
```

- [ ] **Step 3: Write failing design token tests**

```swift
// Tests/OpencodeUsageTrackerAppTests/DesignTokensTests.swift
import XCTest
@testable import OpencodeUsageTrackerApp

final class DesignTokensTests: XCTestCase {
    func testTypographyValues() {
        XCTAssertEqual(DesignSystem.Typography.displayLarge, 24)
        XCTAssertEqual(DesignSystem.Typography.captionSmall, 10)
    }

    func testSpacingValues() {
        XCTAssertEqual(DesignSystem.Spacing.xs, 4)
        XCTAssertEqual(DesignSystem.Spacing.xxl, 32)
    }

    func testUsageStatusSafe() {
        let status = UsageStatus(usedPercentage: 0.5)
        XCTAssertEqual(status, .safe)
    }

    func testUsageStatusWarning() {
        let status = UsageStatus(usedPercentage: 0.75)
        XCTAssertEqual(status, .warning)
    }

    func testUsageStatusCritical() {
        let status = UsageStatus(usedPercentage: 0.95)
        XCTAssertEqual(status, .critical)
    }

    func testUsageStatusBoundarySafe() {
        let status = UsageStatus(usedPercentage: 0.7)
        XCTAssertEqual(status, .warning)
    }

    func testUsageStatusBoundaryWarning() {
        let status = UsageStatus(usedPercentage: 0.9)
        XCTAssertEqual(status, .critical)
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeUsageTrackerAppTests 2>&1`
Expected: Tests pass

- [ ] **Step 5: Commit**

```bash
git -C /Users/aman/Documents/opencode-plugin add opencode-widget/Sources/OpencodeUsageTrackerApp/DesignSystem/ opencode-widget/Tests/OpencodeUsageTrackerAppTests/DesignTokensTests.swift
git -C /Users/aman/Documents/opencode-plugin commit -m "feat: add design system and usage status"
```

---

### Task 3: DeepSeekAPIService

**Files:**
- Create: `Sources/OpencodeUsageTrackerApp/Services/DeepSeekAPIService.swift`
- Test: `Tests/OpencodeUsageTrackerAppTests/DeepSeekAPIServiceTests.swift`

**Interfaces:**
- Produces: `DeepSeekAPIService.fetchBalance(apiKey:session:) async throws -> Double`

- [ ] **Step 1: Write failing test (MockURLSession via protocol)**

```swift
// Tests/OpencodeUsageTrackerAppTests/DeepSeekAPIServiceTests.swift
import XCTest
@testable import OpencodeUsageTrackerApp

final class DeepSeekAPIServiceTests: XCTestCase {
    func testFetchBalanceReturnsBalanceOnSuccess() async throws {
        let json = """
        {"balance_infos": [{"total_balance": "99.95"}]}
        """
        MockURLProtocol.defaultData = json.data(using: .utf8)
        MockURLProtocol.defaultStatusCode = 200

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let balance = try await DeepSeekAPIService.fetchBalance(apiKey: "test-key", session: session)
        XCTAssertEqual(balance, 99.95)
    }

    func testFetchBalanceThrowsOnNetworkError() async {
        MockURLProtocol.defaultError = NSError(domain: "test", code: -1)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        await XCTAssertThrowsError(try await DeepSeekAPIService.fetchBalance(apiKey: "test-key", session: session))
    }

    func testFetchBalanceThrowsOnBadJSON() async {
        MockURLProtocol.defaultData = "not-json".data(using: .utf8)
        MockURLProtocol.defaultStatusCode = 200

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        await XCTAssertThrowsError(try await DeepSeekAPIService.fetchBalance(apiKey: "test-key", session: session))
    }

    func testFetchBalanceThrowsOnHTTPError() async {
        MockURLProtocol.defaultStatusCode = 401

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        await XCTAssertThrowsError(try await DeepSeekAPIService.fetchBalance(apiKey: "test-key", session: session))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeUsageTrackerAppTests 2>&1`
Expected: Compile error or test failure (DeepSeekAPIService not defined)

- [ ] **Step 3: Write DeepSeekAPIService**

```swift
import Foundation

public enum DeepSeekAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid DeepSeek API URL"
        case .invalidResponse: return "Invalid response from DeepSeek"
        case .httpError(let code): return "HTTP error \(code)"
        case .decodingFailed: return "Failed to parse DeepSeek balance"
        case .networkError(let error): return error.localizedDescription
        }
    }
}

public enum DeepSeekAPIService {
    static let balanceURL = URL(string: "https://api.deepseek.com/user/balance")!

    public static func fetchBalance(apiKey: String, session: URLSession = .shared) async throws -> Double {
        var request = URLRequest(url: balanceURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DeepSeekAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DeepSeekAPIError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let infos = json["balance_infos"] as? [[String: Any]],
              let first = infos.first,
              let balanceStr = first["total_balance"] as? String,
              let balance = Double(balanceStr) else {
            throw DeepSeekAPIError.decodingFailed
        }
        return balance
    }
}
```

- [ ] **Step 4: Create MockURLProtocol in the test target**

```swift
// Add to Tests/OpencodeUsageTrackerAppTests/MockURLProtocol.swift
import XCTest

class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [String: (data: Data?, error: Error?, statusCode: Int)] = [:]
    nonisolated(unsafe) static var defaultData: Data?
    nonisolated(unsafe) static var defaultError: Error?
    nonisolated(unsafe) static var defaultStatusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let urlStr = request.url?.absoluteString ?? ""
        let response: (data: Data?, error: Error?, statusCode: Int)
        if let match = Self.responses[urlStr] {
            response = match
        } else {
            response = (Self.defaultData, Self.defaultError, Self.defaultStatusCode)
        }

        if let error = response.error {
            client?.urlProtocol(self, didFailWithError: error)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let httpResponse = HTTPURLResponse(url: request.url!, statusCode: response.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        if let data = response.data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
```

- [ ] **Step 5: Add XCTAssertThrowsError async helper**

```swift
// Add to Tests/OpencodeUsageTrackerAppTests/XCTestAsyncHelpers.swift
func XCTAssertThrowsError<T>(_ expression: @autoclosure () async throws -> T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) async {
    do {
        _ = try await expression()
        XCTFail("Expected error but got success", file: file, line: line)
    } catch {
        // Expected
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeUsageTrackerAppTests 2>&1`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git -C /Users/aman/Documents/opencode-plugin add opencode-widget/Sources/OpencodeUsageTrackerApp/Services/DeepSeekAPIService.swift opencode-widget/Tests/OpencodeUsageTrackerAppTests/DeepSeekAPIServiceTests.swift opencode-widget/Tests/OpencodeUsageTrackerAppTests/MockURLProtocol.swift opencode-widget/Tests/OpencodeUsageTrackerAppTests/XCTestAsyncHelpers.swift
git -C /Users/aman/Documents/opencode-plugin commit -m "feat: add DeepSeekAPIService with tests"
```

---

### Task 4: MiniMaxAPIService

**Files:**
- Create: `Sources/OpencodeUsageTrackerApp/Services/MiniMaxAPIService.swift`
- Test: `Tests/OpencodeUsageTrackerAppTests/MiniMaxAPIServiceTests.swift`

**Interfaces:**
- Produces: `MiniMaxAPIService.fetchUsage(apiKey:session:) async throws -> [MiniMaxModelRemain]`

- [ ] **Step 1: Write failing MiniMaxAPIService tests**

```swift
// Tests/OpencodeUsageTrackerAppTests/MiniMaxAPIServiceTests.swift
import XCTest
@testable import OpencodeUsageTrackerApp
@testable import OpencodeWidgetShared

final class MiniMaxAPIServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.responses = [:]
        MockURLProtocol.defaultData = nil
        MockURLProtocol.defaultError = nil
        MockURLProtocol.defaultStatusCode = 200
    }

    func testFetchReturnsModelRemainsOnSuccess() async throws {
        let json = """
        {"modelRemains": [
            {"modelName": "minimax-v1", "currentIntervalTotalCount": 200, "currentIntervalRemainingCount": 145, "startTime": 1700000000000, "endTime": 1702592000000, "remainsTime": 259200000}
        ], "baseResp": {"statusCode": 0}}
        """
        MockURLProtocol.defaultData = json.data(using: .utf8)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let models = try await MiniMaxAPIService.fetchUsage(apiKey: "test-key", session: session)
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models[0].modelName, "minimax-v1")
        XCTAssertEqual(models[0].currentIntervalTotalCount, 200)
        XCTAssertEqual(models[0].currentIntervalRemainingCount, 145)
    }

    func testFetchReturnsMultipleModels() async throws {
        let json = """
        {"modelRemains": [
            {"modelName": "model-a", "currentIntervalTotalCount": 100, "currentIntervalRemainingCount": 80, "startTime": 1700000000000, "endTime": 1702592000000, "remainsTime": 259200000},
            {"modelName": "model-b", "currentIntervalTotalCount": 200, "currentIntervalRemainingCount": 150, "startTime": 1700000000000, "endTime": 1702592000000, "remainsTime": 259200000}
        ], "baseResp": {"statusCode": 0}}
        """
        MockURLProtocol.defaultData = json.data(using: .utf8)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let models = try await MiniMaxAPIService.fetchUsage(apiKey: "test-key", session: session)
        XCTAssertEqual(models.count, 2)
    }

    func testFetchThrowsOnNetworkError() async {
        MockURLProtocol.defaultError = NSError(domain: "test", code: -1)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        await XCTAssertThrowsError(try await MiniMaxAPIService.fetchUsage(apiKey: "test-key", session: session))
    }

    func testFetchThrowsOnHTTPError() async {
        MockURLProtocol.defaultStatusCode = 401

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        await XCTAssertThrowsError(try await MiniMaxAPIService.fetchUsage(apiKey: "test-key", session: session))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeUsageTrackerAppTests 2>&1`
Expected: Compile error or test fail (MiniMaxAPIService not defined)

- [ ] **Step 3: Write MiniMaxAPIService**

```swift
import Foundation
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

public enum MiniMaxAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid MiniMax API URL"
        case .invalidResponse: return "Invalid response from MiniMax"
        case .httpError(let code): return "HTTP error \(code)"
        case .decodingFailed: return "Failed to parse MiniMax usage"
        case .networkError(let error): return error.localizedDescription
        }
    }
}

public enum MiniMaxAPIService {
    static let usageURL = URL(string: "https://api.minimax.io/v1/api/openplatform/coding_plan/remains")!

    public static func fetchUsage(apiKey: String, session: URLSession = .shared) async throws -> [MiniMaxModelRemain] {
        var request = URLRequest(url: usageURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MiniMaxAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiniMaxAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MiniMaxAPIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            let planResponse = try decoder.decode(MiniMaxCodingPlanResponse.self, from: data)
            return planResponse.modelRemains
        } catch {
            throw MiniMaxAPIError.decodingFailed
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeUsageTrackerAppTests 2>&1`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git -C /Users/aman/Documents/opencode-plugin add opencode-widget/Sources/OpencodeUsageTrackerApp/Services/MiniMaxAPIService.swift opencode-widget/Tests/OpencodeUsageTrackerAppTests/MiniMaxAPIServiceTests.swift
git -C /Users/aman/Documents/opencode-plugin commit -m "feat: add MiniMaxAPIService with tests"
```

---

### Task 5: DatabaseService

**Files:**
- Create: `Sources/OpencodeUsageTrackerApp/Services/DatabaseService.swift`
- Test: `Tests/OpencodeUsageTrackerAppTests/DatabaseServiceTests.swift`

**Interfaces:**
- Produces: `DatabaseService.queryUsage(dbPath:) -> [DailyUsageRow]`, `DatabaseService.queryPerModelUsage(dbPath:) -> [ModelUsageRow]`

- [ ] **Step 1: Write DatabaseService tests**

```swift
// Tests/OpencodeUsageTrackerAppTests/DatabaseServiceTests.swift
import XCTest
import SQLite3
@testable import OpencodeUsageTrackerApp
@testable import OpencodeWidgetShared

final class DatabaseServiceTests: XCTestCase {
    var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tmp = FileManager.default.temporaryDirectory
        tempDBPath = tmp.appendingPathComponent("testdb-\(UUID().uuidString).db").path
        createDB()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDBPath)
        tempDBPath = nil
        super.tearDown()
    }

    // MARK: - queryUsage

    func testQueryUsageReturnsEmptyForNoData() {
        let rows = DatabaseService.queryUsage(dbPath: tempDBPath)
        XCTAssertTrue(rows.isEmpty)
    }

    func testQueryUsageAggregatesByProvider() {
        insertSession(dayOffset: 0, provider: "deepseek", tokensInput: 100, tokensOutput: 50, cost: 1.5)
        insertSession(dayOffset: 0, provider: "minimax", tokensInput: 200, tokensOutput: 100, cost: 3.0)

        let rows = DatabaseService.queryUsage(dbPath: tempDBPath)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].deepseekTokens, 150)
        XCTAssertEqual(rows[0].minimaxTokens, 300)
    }

    // MARK: - queryPerModelUsage

    func testQueryPerModelUsageReturnsPerModelRows() {
        insertSession(dayOffset: 0, provider: "deepseek", modelId: "deepseek-v4", tokensInput: 100, tokensOutput: 50, cost: 1.5)
        insertSession(dayOffset: 0, provider: "deepseek", modelId: "deepseek-chat", tokensInput: 200, tokensOutput: 0, cost: 2.0)

        let rows = DatabaseService.queryPerModelUsage(dbPath: tempDBPath)
        XCTAssertEqual(rows.count, 2)
        let v4 = rows.first { $0.modelId == "deepseek-v4" }
        let chat = rows.first { $0.modelId == "deepseek-chat" }
        XCTAssertEqual(v4?.tokens, 150)
        XCTAssertEqual(chat?.tokens, 200)
    }

    func testQueryPerModelUsageExcludesNullModel() {
        var db: OpaquePointer?
        guard sqlite3_open(tempDBPath, &db) == SQLITE_OK, let db = db else { return XCTFail() }
        defer { sqlite3_close(db) }

        let timestamp = Int(Date().timeIntervalSince1970)
        let sql = "INSERT INTO session (time_created, model, tokens_input, tokens_output, cost) VALUES (?, NULL, 100, 0, 1.0);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return XCTFail() }
        sqlite3_bind_int64(stmt, 1, sqlite3_int64(timestamp))
        guard sqlite3_step(stmt) == SQLITE_DONE else { XCTFail(); sqlite3_finalize(stmt); return }
        sqlite3_finalize(stmt)

        let rows = DatabaseService.queryPerModelUsage(dbPath: tempDBPath)
        XCTAssertTrue(rows.isEmpty)
    }

    // MARK: - Helpers

    private func createDB() {
        var db: OpaquePointer?
        guard sqlite3_open(tempDBPath, &db) == SQLITE_OK, let db = db else {
            XCTFail("Failed to create temp DB")
            return
        }
        defer { sqlite3_close(db) }

        let createSQL = """
        CREATE TABLE IF NOT EXISTS session (
            time_created INTEGER,
            model TEXT,
            tokens_input INTEGER,
            tokens_output INTEGER,
            cost REAL
        );
        """
        var errMsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, createSQL, nil, nil, &errMsg) == SQLITE_OK else {
            sqlite3_free(errMsg)
            XCTFail("Failed to create table")
            return
        }
    }

    private func insertSession(dayOffset: Int, provider: String, modelId: String = "default", tokensInput: Int = 0, tokensOutput: Int = 0, cost: Double = 0) {
        var db: OpaquePointer?
        guard sqlite3_open(tempDBPath, &db) == SQLITE_OK, let db = db else {
            XCTFail("Failed to open DB")
            return
        }
        defer { sqlite3_close(db) }

        let timestamp = Int(Date().timeIntervalSince1970) - dayOffset * 86400
        let modelJSON = "{\"providerID\": \"\(provider)\", \"id\": \"\(modelId)\"}"

        let sql = "INSERT INTO session (time_created, model, tokens_input, tokens_output, cost) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { XCTFail(); return }
        sqlite3_bind_int64(stmt, 1, sqlite3_int64(timestamp))
        sqlite3_bind_text(stmt, 2, (modelJSON as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 3, sqlite3_int64(tokensInput))
        sqlite3_bind_int64(stmt, 4, sqlite3_int64(tokensOutput))
        sqlite3_bind_double(stmt, 5, cost)
        guard sqlite3_step(stmt) == SQLITE_DONE else { XCTFail(); sqlite3_finalize(stmt); return }
        sqlite3_finalize(stmt)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeUsageTrackerAppTests 2>&1`
Expected: Compile error (DatabaseService not defined)

- [ ] **Step 3: Write DatabaseService**

```swift
import Foundation
import SQLite3
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

public enum DatabaseService {
    public static func queryUsage(dbPath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db") -> [DailyUsageRow] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            sqlite3_close(db)
            return []
        }

        let query = """
        SELECT
          date(time_created, 'unixepoch') as day,
          json_extract(model, '$.providerID') as provider,
          SUM(tokens_input + tokens_output) as total_tokens,
          SUM(cost) as total_cost
        FROM session
        WHERE model IS NOT NULL AND model != ''
          AND time_created > strftime('%s', 'now', '-30 days')
        GROUP BY day, provider
        ORDER BY day
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return []
        }

        var rowsByDate: [String: DailyUsageRow] = [:]

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let dayPtr = sqlite3_column_text(statement, 0),
                  let providerPtr = sqlite3_column_text(statement, 1) else { continue }
            let day = String(cString: dayPtr)
            let provider = String(cString: providerPtr)
            let tokens = Int(sqlite3_column_int64(statement, 2))
            let cost = sqlite3_column_double(statement, 3)

            var row = rowsByDate[day] ?? DailyUsageRow(date: day)
            if provider == "deepseek" {
                row.deepseekTokens += tokens
                row.deepseekCost += cost
            } else if provider == "minimax" {
                row.minimaxTokens += tokens
                row.minimaxCost += cost
            }
            rowsByDate[day] = row
        }

        sqlite3_finalize(statement)
        sqlite3_close(db)

        return rowsByDate.values.sorted { $0.date < $1.date }
    }

    public static func queryPerModelUsage(dbPath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db") -> [ModelUsageRow] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            sqlite3_close(db)
            return []
        }

        let query = """
        SELECT
          date(time_created, 'unixepoch') as day,
          json_extract(model, '$.providerID') as provider,
          json_extract(model, '$.id') as model_id,
          SUM(tokens_input + tokens_output) as total_tokens,
          SUM(cost) as total_cost
        FROM session
        WHERE model IS NOT NULL AND model != ''
          AND time_created > strftime('%s', 'now', '-30 days')
        GROUP BY day, provider, model_id
        ORDER BY day
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return []
        }

        var rows: [ModelUsageRow] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let dayPtr = sqlite3_column_text(statement, 0),
                  let providerPtr = sqlite3_column_text(statement, 1),
                  let modelIdPtr = sqlite3_column_text(statement, 2) else { continue }
            let day = String(cString: dayPtr)
            let provider = String(cString: providerPtr)
            let modelId = String(cString: modelIdPtr)
            let tokens = Int(sqlite3_column_int64(statement, 3))
            let cost = sqlite3_column_double(statement, 4)

            rows.append(ModelUsageRow(date: day, provider: provider, modelId: modelId, tokens: tokens, cost: cost))
        }

        sqlite3_finalize(statement)
        sqlite3_close(db)

        return rows
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeUsageTrackerAppTests 2>&1`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git -C /Users/aman/Documents/opencode-plugin add opencode-widget/Sources/OpencodeUsageTrackerApp/Services/DatabaseService.swift opencode-widget/Tests/OpencodeUsageTrackerAppTests/DatabaseServiceTests.swift
git -C /Users/aman/Documents/opencode-plugin commit -m "feat: add DatabaseService with per-model query support"
```

---

### Task 6: NotificationManager

**Files:**
- Create: `Sources/OpencodeUsageTrackerApp/Services/NotificationManager.swift`
- Test: `Tests/OpencodeUsageTrackerAppTests/NotificationManagerTests.swift`

**Interfaces:**
- Produces: `NotificationManager.checkThresholds(models: [MiniMaxModelRemain]) -> [(modelName: String, level: NotificationLevel)]` where `NotificationLevel = warning | critical`

- [ ] **Step 1: Write failing NotificationManager tests**

```swift
// Tests/OpencodeUsageTrackerAppTests/NotificationManagerTests.swift
import XCTest
@testable import OpencodeUsageTrackerApp
@testable import OpencodeWidgetShared

final class NotificationManagerTests: XCTestCase {
    func testWarningAt85Percent() {
        let remain = MiniMaxModelRemain(modelName: "test", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 15, startTime: 0, endTime: 0, remainsTime: 0)
        let alerts = NotificationManager.checkThresholds(models: [remain])
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts[0].level, .warning)
    }

    func testCriticalAt95Percent() {
        let remain = MiniMaxModelRemain(modelName: "test", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 5, startTime: 0, endTime: 0, remainsTime: 0)
        let alerts = NotificationManager.checkThresholds(models: [remain])
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts[0].level, .critical)
    }

    func testNoAlertBelow85Percent() {
        let remain = MiniMaxModelRemain(modelName: "test", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 20, startTime: 0, endTime: 0, remainsTime: 0)
        let alerts = NotificationManager.checkThresholds(models: [remain])
        XCTAssertTrue(alerts.isEmpty)
    }

    func testCriticalTakesPriorityOverWarning() {
        let remain = MiniMaxModelRemain(modelName: "test", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 5, startTime: 0, endTime: 0, remainsTime: 0)
        let alerts = NotificationManager.checkThresholds(models: [remain])
        XCTAssertEqual(alerts[0].level, .critical)
    }

    func testMultipleModelsGenerateSeparateAlerts() {
        let models = [
            MiniMaxModelRemain(modelName: "model-a", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 10, startTime: 0, endTime: 0, remainsTime: 0),
            MiniMaxModelRemain(modelName: "model-b", currentIntervalTotalCount: 200, currentIntervalRemainingCount: 180, startTime: 0, endTime: 0, remainsTime: 0),
        ]
        let alerts = NotificationManager.checkThresholds(models: models)
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts[0].modelName, "model-a")
    }

    func testDeduplicationReturnsOnlyNewAlerts() {
        let model = MiniMaxModelRemain(modelName: "test", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 10, startTime: 0, endTime: 0, remainsTime: 0)

        // First call returns the alert and marks it sent internally
        let firstRun = NotificationManager.checkThresholds(models: [model])
        XCTAssertEqual(firstRun.count, 1)

        // Second call with same usage should be deduplicated
        let secondRun = NotificationManager.checkThresholds(models: [model])
        XCTAssertTrue(secondRun.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeUsageTrackerAppTests 2>&1`
Expected: Compile errors (NotificationManager, RegisterManager not defined)

- [ ] **Step 3: Write NotificationManager**

```swift
import Foundation
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

public enum NotificationLevel: String, Codable {
    case warning
    case critical
}

public struct ModelAlert: Equatable {
    public let modelName: String
    public let level: NotificationLevel
}

public enum NotificationManager {
    static let warningThreshold: Double = 0.85
    static let criticalThreshold: Double = 0.95

    public static func checkThresholds(models: [MiniMaxModelRemain]) -> [ModelAlert] {
        var alerts: [ModelAlert] = []

        for model in models {
            let usedPct = model.usagePercentage

            if usedPct >= criticalThreshold {
                let alert = ModelAlert(modelName: model.modelName, level: .critical)
                if !hasAlertBeenSent(for: model.modelName, level: .critical) {
                    alerts.append(alert)
                    markAlertSent(for: model.modelName, level: .critical)
                }
            } else if usedPct >= warningThreshold {
                let alert = ModelAlert(modelName: model.modelName, level: .warning)
                if !hasAlertBeenSent(for: model.modelName, level: .warning) {
                    alerts.append(alert)
                    markAlertSent(for: model.modelName, level: .warning)
                }
            }
        }

        return alerts
    }

    private static var alertRegistry: [String: Date] = [:]

    private static func hasAlertBeenSent(for modelName: String, level: NotificationLevel) -> Bool {
        let key = "\(modelName)-\(level.rawValue)"
        guard let sentDate = alertRegistry[key] else { return false }
        // Reset after 24 hours
        return Date().timeIntervalSince(sentDate) < 86400
    }

    static func markAlertSent(for modelName: String, level: NotificationLevel) {
        let key = "\(modelName)-\(level.rawValue)"
        alertRegistry[key] = Date()
    }

    static func resetAlerts() {
        alertRegistry = [:]
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeUsageTrackerAppTests 2>&1`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git -C /Users/aman/Documents/opencode-plugin add opencode-widget/Sources/OpencodeUsageTrackerApp/Services/NotificationManager.swift opencode-widget/Tests/OpencodeUsageTrackerAppTests/NotificationManagerTests.swift
git -C /Users/aman/Documents/opencode-plugin commit -m "feat: add NotificationManager with threshold checks"
```

---

### Task 7: UsageViewModel

**Files:**
- Create: `Sources/OpencodeUsageTrackerApp/ViewModels/UsageViewModel.swift`
- Test: `Tests/OpencodeUsageTrackerAppTests/UsageViewModelTests.swift`

**Interfaces:**
- Produces: `UsageViewModel` (@Observable) with `state`, `deepseekBalance`, `minimaxModels`, `dailyUsage`, `perModelUsage`, `lastUpdated`, `load()`, `refresh()`, snapshot management
- Consumes: `DeepSeekAPIService`, `MiniMaxAPIService`, `DatabaseService`, `NotificationManager`, `AuthReader`, `DataStore`

- [ ] **Step 1: Write failing UsageViewModel tests**

```swift
// Tests/OpencodeUsageTrackerAppTests/UsageViewModelTests.swift
import XCTest
@testable import OpencodeUsageTrackerApp
@testable import OpencodeWidgetShared

final class UsageViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.responses = [:]
        MockURLProtocol.defaultData = nil
        MockURLProtocol.defaultError = nil
        MockURLProtocol.defaultStatusCode = 200
        NotificationManager.resetAlerts()
    }

    func testInitialStateIsLoading() {
        let vm = UsageViewModel()
        XCTAssertEqual(vm.state, .loading)
    }

    func testLoadWithMissingAuthShowsOnboarding() async {
        let vm = UsageViewModel(authPath: "/nonexistent/auth.json")
        await vm.load()
        XCTAssertEqual(vm.state, .onboarding)
    }

    func testRefreshUpdatesBalances() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let authPath = tmp.appendingPathComponent("test-auth-\(UUID().uuidString).json").path
        let authJSON = """
        {"deepseek": {"key": "ds-test"}, "minimax": {"key": "mm-test"}}
        """
        try authJSON.write(toFile: authPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: authPath) }

        MockURLProtocol.responses = [
            "https://api.deepseek.com/user/balance": ("{\"balance_infos\": [{\"total_balance\": \"42.00\"}]}".data(using: .utf8), nil, 200),
            "https://api.minimax.io/v1/api/openplatform/coding_plan/remains": ("{\"modelRemains\": [], \"baseResp\": {\"statusCode\": 0}}".data(using: .utf8), nil, 200),
        ]

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let vm = UsageViewModel(authPath: authPath)
        await vm.refresh(session: session, dbPath: "/nonexistent/db.db")

        if case .loaded(let data) = vm.state {
            XCTAssertEqual(data.deepseekBalance, 42.00)
        } else {
            XCTFail("Expected loaded state, got \(vm.state)")
        }
    }

    func testRefreshWithNetworkErrorShowsError() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let authPath = tmp.appendingPathComponent("test-auth-\(UUID().uuidString).json").path
        let authJSON = """
        {"deepseek": {"key": "ds-test"}, "minimax": {"key": "mm-test"}}
        """
        try authJSON.write(toFile: authPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: authPath) }

        MockURLProtocol.defaultError = NSError(domain: "test", code: -1, userInfo: nil)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let vm = UsageViewModel(authPath: authPath)
        await vm.refresh(session: session, dbPath: "/nonexistent/db.db")

        if case .error(let message) = vm.state {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected error state, got \(vm.state)")
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeUsageTrackerAppTests 2>&1`
Expected: Compile errors (UsageViewModel not defined)

- [ ] **Step 3: Write UsageViewModel**

```swift
import Foundation
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

public enum ViewState: Equatable {
    case loading
    case loaded(UsageData)
    case error(String)
    case onboarding
}

public struct UsageData: Equatable {
    public let deepseekBalance: Double?
    public let minimaxModels: [MiniMaxModelRemain]
    public let dailyUsage: [DailyUsageRow]
    public let perModelUsage: [ModelUsageRow]
    public let lastUpdated: Date

    public init(deepseekBalance: Double? = nil, minimaxModels: [MiniMaxModelRemain] = [], dailyUsage: [DailyUsageRow] = [], perModelUsage: [ModelUsageRow] = [], lastUpdated: Date = Date()) {
        self.deepseekBalance = deepseekBalance
        self.minimaxModels = minimaxModels
        self.dailyUsage = dailyUsage
        self.perModelUsage = perModelUsage
        self.lastUpdated = lastUpdated
    }
}

@Observable
public final class UsageViewModel {
    public var state: ViewState = .loading
    public var lastRefresh: Date?
    public var autoRefreshInterval: TimeInterval = 900 // 15 minutes

    private let authPath: String
    private let dbPath: String
    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?

    public init(authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json", dbPath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db") {
        self.authPath = authPath
        self.dbPath = dbPath
    }

    public func load() async {
        guard AuthReader.readCredentials(authPath: authPath) != nil else {
            state = .onboarding
            return
        }
        await refresh()
        startAutoRefresh()
    }

    public func refresh(session: URLSession = .shared, dbPath: String? = nil) async {
        let effectiveDB = dbPath ?? self.dbPath

        guard let creds = AuthReader.readCredentials(authPath: authPath) else {
            state = .onboarding
            return
        }

        state = .loading

        do {
            async let dsBalance = DeepSeekAPIService.fetchBalance(apiKey: creds.deepseekKey, session: session)
            async let mmModels = MiniMaxAPIService.fetchUsage(apiKey: creds.minimaxKey, session: session)

            let usage = DatabaseService.queryUsage(dbPath: effectiveDB)
            let perModelUsage = DatabaseService.queryPerModelUsage(dbPath: effectiveDB)

            let (balance, models) = try await (dsBalance, mmModels)

            // Check notification thresholds
            let alerts = NotificationManager.checkThresholds(models: models)
            for alert in alerts {
                sendNotification(alert: alert)
            }

            let data = UsageData(
                deepseekBalance: balance,
                minimaxModels: models,
                dailyUsage: usage,
                perModelUsage: perModelUsage,
                lastUpdated: Date()
            )

            state = .loaded(data)
            lastRefresh = Date()

            // Persist snapshot
            let cache = WidgetCache(
                lastUpdated: Date(),
                deepseek: ProviderBalance(balance: balance, currency: "USD"),
                minimax: ProviderBalance(balance: Double(models.reduce(0) { $0 + $1.currentIntervalRemainingCount }), currency: "USD"),
                minimaxUsage: MiniMaxUsage(remainingPrompts: models.reduce(0) { $0 + $1.currentIntervalRemainingCount }, totalPrompts: models.reduce(0) { $0 + $1.currentIntervalTotalCount }),
                dailyUsage: usage
            )
            DataStore.save(cache: cache)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public func startAutoRefresh() {
        stopAutoRefresh()
        timer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.refresh()
            }
        }
    }

    public func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func sendNotification(alert: ModelAlert) {
        let notification = NSUserNotification()
        notification.title = "Usage Alert"
        notification.informativeText = alert.level == .critical
            ? "\(alert.modelName) usage critically high (95%+). Check your plan."
            : "\(alert.modelName) usage at 85% or above. Consider upgrading."
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    deinit {
        stopAutoRefresh()
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test --target OpencodeUsageTrackerAppTests 2>&1`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git -C /Users/aman/Documents/opencode-plugin add opencode-widget/Sources/OpencodeUsageTrackerApp/ViewModels/UsageViewModel.swift opencode-widget/Tests/OpencodeUsageTrackerAppTests/UsageViewModelTests.swift
git -C /Users/aman/Documents/opencode-plugin commit -m "feat: add UsageViewModel with state management"
```

---

### Task 8: Reusable UI Components

**Files:**
- Create: `Sources/OpencodeUsageTrackerApp/Components/StatCard.swift`
- Create: `Sources/OpencodeUsageTrackerApp/Components/ProgressBar.swift`
- Create: `Sources/OpencodeUsageTrackerApp/Components/ModelCard.swift`
- Create: `Sources/OpencodeUsageTrackerApp/Components/TimelineChart.swift`
- Create: `Sources/OpencodeUsageTrackerApp/Components/StatusIndicator.swift`
- Create: `Sources/OpencodeUsageTrackerApp/Components/EmptyStateView.swift`
- Create: `Sources/OpencodeUsageTrackerApp/Components/ErrorStateView.swift`
- Create: `Sources/OpencodeUsageTrackerApp/Components/LoadingView.swift`

**Interfaces:**
- Produces: Reusable SwiftUI views. Each view is a standalone `View` struct.

- [ ] **Step 1: Create StatCard.swift**

```swift
import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .accentColor

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            Text(value)
                .font(.system(size: DesignSystem.Typography.headingLarge))
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: DesignSystem.Typography.caption))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(DesignSystem.Radius.md)
    }
}
```

- [ ] **Step 2: Create ProgressBar.swift**

```swift
import SwiftUI

struct ProgressBar: View {
    let value: Double // 0.0 to 1.0
    var height: CGFloat = 8

    private var barColor: Color {
        switch UsageStatus(usedPercentage: value) {
        case .safe: return DesignSystem.Color.safe
        case .warning: return DesignSystem.Color.warning
        case .critical: return DesignSystem.Color.critical
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(Color(.separatorColor).opacity(0.2))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(barColor)
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)), height: height)
            }
        }
        .frame(height: height)
    }
}
```

- [ ] **Step 3: Create StatusIndicator.swift**

```swift
import SwiftUI

struct StatusIndicator: View {
    let status: UsageStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private var color: Color {
        switch status {
        case .safe: return DesignSystem.Color.safe
        case .warning: return DesignSystem.Color.warning
        case .critical: return DesignSystem.Color.critical
        }
    }
}
```

- [ ] **Step 4: Create ModelCard.swift**

```swift
import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct ModelCard: View {
    let modelName: String
    let provider: String
    let totalPrompts: Int?
    let remainingPrompts: Int?
    let tokens: Int
    let cost: Double

    private var usagePercentage: Double {
        guard let total = totalPrompts, total > 0 else { return 0 }
        return Double(total - (remainingPrompts ?? 0)) / Double(total)
    }

    private var statusColor: Color {
        switch UsageStatus(usedPercentage: usagePercentage) {
        case .safe: return DesignSystem.Color.safe
        case .warning: return DesignSystem.Color.warning
        case .critical: return DesignSystem.Color.critical
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                StatusIndicator(status: UsageStatus(usedPercentage: usagePercentage))
                Text(modelName)
                    .font(.system(size: DesignSystem.Typography.bodyMedium))
                    .fontWeight(.medium)
                Spacer()
                Text(provider)
                    .font(.system(size: DesignSystem.Typography.caption))
                    .foregroundColor(.secondary)
            }

            if let total = totalPrompts, let remaining = remainingPrompts {
                ProgressBar(value: usagePercentage)
                HStack {
                    Text("\(remaining) / \(total) prompts remaining")
                        .font(.system(size: DesignSystem.Typography.captionSmall))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(UsageStatus(usedPercentage: usagePercentage).label)
                        .font(.system(size: DesignSystem.Typography.captionSmall))
                        .foregroundColor(statusColor)
                }
            }

            if tokens > 0 || cost > 0 {
                HStack {
                    Text("Tokens: \(tokens)")
                        .font(.system(size: DesignSystem.Typography.captionSmall))
                    Spacer()
                    Text(String(format: "Cost: $%.2f", cost))
                        .font(.system(size: DesignSystem.Typography.captionSmall))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}
```

- [ ] **Step 5: Create TimelineChart.swift**

```swift
import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct TimelineChart: View {
    let dailyUsage: [DailyUsageRow]

    private var maxTokens: Int {
        dailyUsage.map(\.totalTokens).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Daily Token Usage")
                .font(.system(size: DesignSystem.Typography.caption))
                .foregroundColor(.secondary)

            HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
                ForEach(dailyUsage.suffix(7)) { row in
                    VStack(spacing: 2) {
                        let deepHeight: CGFloat = maxTokens > 0 ? CGFloat(row.deepseekTokens) / CGFloat(maxTokens) * 80 : 0
                        let miniHeight: CGFloat = maxTokens > 0 ? CGFloat(row.minimaxTokens) / CGFloat(maxTokens) * 80 : 0

                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(DesignSystem.Color.minimaxAccent.opacity(0.7))
                                .frame(height: max(miniHeight, 2))
                            Rectangle()
                                .fill(DesignSystem.Color.deepseekAccent.opacity(0.7))
                                .frame(height: max(deepHeight, 2))
                        }
                        .frame(width: 32)
                        .cornerRadius(DesignSystem.Radius.sm)

                        Text(formatDate(row.date))
                            .font(.system(size: DesignSystem.Typography.captionSmall))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 90)

            HStack(spacing: DesignSystem.Spacing.md) {
                Label("DeepSeek", systemImage: "circle.fill")
                    .font(.system(size: DesignSystem.Typography.captionSmall))
                    .foregroundColor(DesignSystem.Color.deepseekAccent)
                Label("MiniMax", systemImage: "circle.fill")
                    .font(.system(size: DesignSystem.Typography.captionSmall))
                    .foregroundColor(DesignSystem.Color.minimaxAccent)
            }
        }
    }

    private func formatDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count >= 3 else { return date }
        return "\(parts[1])/\(parts[2])"
    }
}
```

- [ ] **Step 6: Create EmptyStateView.swift**

```swift
import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text(title)
                .font(.system(size: DesignSystem.Typography.headingMedium))
                .foregroundColor(.secondary)

            Text(message)
                .font(.system(size: DesignSystem.Typography.bodyMedium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let action, let actionLabel {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 7: Create ErrorStateView.swift**

```swift
import SwiftUI

struct ErrorStateView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(DesignSystem.Color.critical)

            Text("Error")
                .font(.system(size: DesignSystem.Typography.headingMedium))
                .foregroundColor(.primary)

            Text(message)
                .font(.system(size: DesignSystem.Typography.bodyMedium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Button("Retry", action: retryAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 8: Create LoadingView.swift**

```swift
import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.system(size: DesignSystem.Typography.bodyMedium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 9: Commit (no tests needed for simple views)**

```bash
git -C /Users/aman/Documents/opencode-plugin add opencode-widget/Sources/OpencodeUsageTrackerApp/Components/
git -C /Users/aman/Documents/opencode-plugin commit -m "feat: add reusable UI components (StatCard, ProgressBar, ModelCard, TimelineChart, StatusIndicator, Empty/Error/Loading views)"
```

---

### Task 9: OnboardingView

**Files:**
- Create: `Sources/OpencodeUsageTrackerApp/Views/OnboardingView.swift`

**Interfaces:**
- Produces: `OnboardingView` with two text fields for API keys

- [ ] **Step 1: Create OnboardingView.swift**

```swift
import SwiftUI

struct OnboardingView: View {
    @State private var deepseekKey = ""
    @State private var minimaxKey = ""
    @State private var statusMessage = ""
    @State private var isVerifying = false
    let onComplete: () -> Void

    private let authPath: String

    init(authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json", onComplete: @escaping () -> Void) {
        self.authPath = authPath
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("API Keys Required")
                .font(.system(size: DesignSystem.Typography.displayMedium))
                .fontWeight(.bold)

            Text("Enter your API keys to monitor usage.\nKeys are stored locally and never shared.")
                .font(.system(size: DesignSystem.Typography.bodyMedium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("DeepSeek API Key")
                        .font(.system(size: DesignSystem.Typography.caption))
                        .foregroundColor(.secondary)
                    SecureField("sk-...", text: $deepseekKey)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("MiniMax API Key")
                        .font(.system(size: DesignSystem.Typography.caption))
                        .foregroundColor(.secondary)
                    SecureField("mm-...", text: $minimaxKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .frame(maxWidth: 320)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: DesignSystem.Typography.caption))
                    .foregroundColor(statusMessage.contains("Error") ? DesignSystem.Color.critical : DesignSystem.Color.safe)
            }

            Button(action: verifyAndSave) {
                if isVerifying {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Get Started")
                        .frame(maxWidth: 200)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(deepseekKey.isEmpty || minimaxKey.isEmpty || isVerifying)
        }
        .padding(DesignSystem.Spacing.xxl)
        .frame(width: 400, height: 500)
    }

    private func verifyAndSave() {
        guard !deepseekKey.isEmpty, !minimaxKey.isEmpty else { return }
        isVerifying = true
        statusMessage = "Verifying..."

        Task {
            do {
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 10
                let session = URLSession(configuration: config)
                _ = try await DeepSeekAPIService.fetchBalance(apiKey: deepseekKey, session: session)
            } catch {
                await MainActor.run {
                    statusMessage = "DeepSeek key verification failed: \(error.localizedDescription)"
                    isVerifying = false
                }
                return
            }

            do {
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 10
                let session = URLSession(configuration: config)
                _ = try await MiniMaxAPIService.fetchUsage(apiKey: minimaxKey, session: session)
            } catch {
                await MainActor.run {
                    statusMessage = "MiniMax key verification failed: \(error.localizedDescription)"
                    isVerifying = false
                }
                return
            }

            // Save auth file
            let authDict: [String: [String: String]] = [
                "deepseek": ["key": deepseekKey],
                "minimax": ["key": minimaxKey],
            ]
            let url = URL(fileURLWithPath: authPath)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = try? JSONSerialization.data(withJSONObject: authDict, options: .prettyPrinted) {
                try? data.write(to: url)
            }

            await MainActor.run {
                isVerifying = false
                onComplete()
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/aman/Documents/opencode-plugin add opencode-widget/Sources/OpencodeUsageTrackerApp/Views/OnboardingView.swift
git -C /Users/aman/Documents/opencode-plugin commit -m "feat: add onboarding view for API key entry"
```

---

### Task 10: Main Tab Views (Dashboard, Usage, History)

**Files:**
- Create: `Sources/OpencodeUsageTrackerApp/Views/MainView.swift`
- Create: `Sources/OpencodeUsageTrackerApp/Views/DashboardView.swift`
- Create: `Sources/OpencodeUsageTrackerApp/Views/UsageView.swift`
- Create: `Sources/OpencodeUsageTrackerApp/Views/HistoryView.swift`

- [ ] **Step 1: Create MainView.swift**

```swift
import SwiftUI

struct MainView: View {
    @State var viewModel: UsageViewModel

    var body: some View {
        TabView {
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            UsageView(viewModel: viewModel)
                .tabItem {
                    Label("Usage", systemImage: "square.grid.2x2.fill")
                }

            HistoryView(viewModel: viewModel)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
        .frame(minWidth: 300, minHeight: 400)
    }
}
```

- [ ] **Step 2: Create DashboardView.swift**

```swift
import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct DashboardView: View {
    let viewModel: UsageViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Refreshing...")
            case .error(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.refresh() }
                }
            case .onboarding:
                EmptyView()
            case .loaded(let data):
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Stat cards
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                            StatCard(
                                title: "DeepSeek Balance",
                                value: data.deepseekBalance.map { String(format: "$%.2f", $0) } ?? "—",
                                icon: "dollarsign.circle.fill",
                                color: DesignSystem.Color.deepseekAccent
                            )
                            StatCard(
                                title: "MiniMax Prompts Left",
                                value: "\(data.minimaxModels.reduce(0) { $0 + $1.currentIntervalRemainingCount })",
                                icon: "number.circle.fill",
                                color: DesignSystem.Color.minimaxAccent
                            )
                            StatCard(
                                title: "Today's Tokens",
                                value: "\(data.dailyUsage.last?.totalTokens ?? 0)".formattedNumber(),
                                icon: "chart.bar.fill",
                                color: .orange
                            )
                            StatCard(
                                title: "Active Models",
                                value: "\(data.minimaxModels.count + Set(data.perModelUsage.map(\.modelId)).count)",
                                icon: "cpu.fill",
                                color: .purple
                            )
                        }

                        // Trend chart
                        if !data.dailyUsage.isEmpty {
                            TimelineChart(dailyUsage: data.dailyUsage)
                                .padding()
                                .background(Color(.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(DesignSystem.Radius.lg)
                        }

                        // Last updated
                        HStack {
                            Spacer()
                            Text("Last updated: \(data.lastUpdated, style: .time)")
                                .font(.system(size: DesignSystem.Typography.captionSmall))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
                .toolbar {
                    ToolbarItem {
                        Button("Refresh") {
                            Task { await viewModel.refresh() }
                        }
                    }
                }
            }
        }
    }
}

extension Int {
    func formattedNumber() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
```

- [ ] **Step 3: Create UsageView.swift**

```swift
import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct UsageView: View {
    let viewModel: UsageViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Loading usage...")
            case .error(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.refresh() }
                }
            case .onboarding:
                EmptyView()
            case .loaded(let data):
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        if !data.minimaxModels.isEmpty {
                            Text("MiniMax")
                                .font(.system(size: DesignSystem.Typography.headingLarge))
                                .fontWeight(.semibold)

                            ForEach(data.minimaxModels) { model in
                                ModelCard(
                                    modelName: model.modelName,
                                    provider: "MiniMax",
                                    totalPrompts: model.currentIntervalTotalCount,
                                    remainingPrompts: model.currentIntervalRemainingCount,
                                    tokens: 0,
                                    cost: 0
                                )
                            }
                        }

                        // Group per-model DB data by provider
                        let dsModels = data.perModelUsage.filter { $0.provider == "deepseek" }
                        let mmModels = data.perModelUsage.filter { $0.provider == "minimax" }

                        if !dsModels.isEmpty {
                            Text("DeepSeek")
                                .font(.system(size: DesignSystem.Typography.headingLarge))
                                .fontWeight(.semibold)

                            ForEach(aggregateByModel(models: dsModels), id: \.modelId) { agg in
                                ModelCard(
                                    modelName: agg.modelId,
                                    provider: "DeepSeek",
                                    totalPrompts: nil,
                                    remainingPrompts: nil,
                                    tokens: agg.tokens,
                                    cost: agg.cost
                                )
                            }
                        }

                        if !mmModels.isEmpty {
                            Text("MiniMax (DB History)")
                                .font(.system(size: DesignSystem.Typography.headingLarge))
                                .fontWeight(.semibold)

                            ForEach(aggregateByModel(models: mmModels), id: \.modelId) { agg in
                                ModelCard(
                                    modelName: agg.modelId,
                                    provider: "MiniMax",
                                    totalPrompts: nil,
                                    remainingPrompts: nil,
                                    tokens: agg.tokens,
                                    cost: agg.cost
                                )
                            }
                        }

                        if data.minimaxModels.isEmpty && dsModels.isEmpty && mmModels.isEmpty {
                            EmptyStateView(
                                title: "No Usage Data",
                                message: "Usage data will appear once you start using AI models.",
                                action: { Task { await viewModel.refresh() } },
                                actionLabel: "Refresh"
                            )
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
                .toolbar {
                    ToolbarItem {
                        Button("Refresh") {
                            Task { await viewModel.refresh() }
                        }
                    }
                }
            }
        }
    }

    private func aggregateByModel(models: [ModelUsageRow]) -> [(modelId: String, tokens: Int, cost: Double)] {
        var dict: [String: (tokens: Int, cost: Double)] = [:]
        for m in models {
            dict[m.modelId, default: (0, 0)].tokens += m.tokens
            dict[m.modelId, default: (0, 0)].cost += m.cost
        }
        return dict.map { ($0.key, $0.value.tokens, $0.value.cost) }
            .sorted { $0.modelId < $1.modelId }
    }
}
```

- [ ] **Step 4: Create HistoryView.swift**

```swift
import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

enum TimeRange: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case all = "All"

    var dayLimit: Int {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .all: return 365
        }
    }
}

struct HistoryView: View {
    let viewModel: UsageViewModel
    @State private var selectedRange: TimeRange = .week

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Loading history...")
            case .error(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.refresh() }
                }
            case .onboarding:
                EmptyView()
            case .loaded(let data):
                VStack(spacing: 0) {
                    Picker("Time Range", selection: $selectedRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(DesignSystem.Spacing.md)

                    let filtered = filterUsage(data.dailyUsage, range: selectedRange)

                    if filtered.isEmpty {
                        EmptyStateView(
                            title: "No History",
                            message: "No usage data for the selected time range."
                        )
                    } else {
                        List(filtered.reversed()) { row in
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(row.date)
                                    .font(.system(size: DesignSystem.Typography.bodyMedium))
                                    .fontWeight(.medium)

                                HStack {
                                    Label("DeepSeek: \(row.deepseekTokens) tokens", systemImage: "circle.fill")
                                        .font(.system(size: DesignSystem.Typography.captionSmall))
                                        .foregroundColor(DesignSystem.Color.deepseekAccent)
                                    Spacer()
                                    Text(String(format: "$%.2f", row.deepseekCost))
                                        .font(.system(size: DesignSystem.Typography.captionSmall))
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Label("MiniMax: \(row.minimaxTokens) tokens", systemImage: "circle.fill")
                                        .font(.system(size: DesignSystem.Typography.captionSmall))
                                        .foregroundColor(DesignSystem.Color.minimaxAccent)
                                    Spacer()
                                    Text(String(format: "$%.2f", row.minimaxCost))
                                        .font(.system(size: DesignSystem.Typography.captionSmall))
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Spacer()
                                    Text(String(format: "Total: $%.2f", row.totalCost))
                                        .font(.system(size: DesignSystem.Typography.captionSmall))
                                        .fontWeight(.medium)
                                }
                            }
                            .padding(.vertical, DesignSystem.Spacing.xs)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem {
                        Button("Refresh") {
                            Task { await viewModel.refresh() }
                        }
                    }
                }
            }
        }
    }

    private func filterUsage(_ usage: [DailyUsageRow], range: TimeRange) -> [DailyUsageRow] {
        guard range != .all else { return usage }
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -range.dayLimit, to: Date()) ?? Date()
        return usage.filter { row in
            guard let date = dateFromString(row.date) else { return true }
            return date >= cutoff
        }
    }

    private func dateFromString(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }
}
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/aman/Documents/opencode-plugin add opencode-widget/Sources/OpencodeUsageTrackerApp/Views/
git -C /Users/aman/Documents/opencode-plugin commit -m "feat: add main views (Dashboard, Usage, History, MainView)"
```

---

### Task 11: App entry point + wiring

**Files:**
- Create: `Sources/OpencodeUsageTrackerApp/App.swift`

- [ ] **Step 1: Create App.swift**

```swift
import SwiftUI

@main
struct OpencodeUsageTrackerApp: App {
    @State private var viewModel = UsageViewModel()
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingView { Task { await handleOnboardingComplete() } }
                } else {
                    MainView(viewModel: viewModel)
                        .frame(minWidth: 300, minHeight: 400)
                }
            }
            .task {
                await viewModel.load()
                if viewModel.state == .onboarding {
                    showOnboarding = true
                }
            }
        }
        .windowResizability(.contentSize)
        .windowTitle("Usage Tracker")
    }

    private func handleOnboardingComplete() async {
        showOnboarding = false
        await viewModel.load()
    }
}
```

- [ ] **Step 2: Build the app to verify it compiles**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift build --target OpencodeUsageTrackerApp 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Run all tests**

Run: `cd /Users/aman/Documents/opencode-plugin/opencode-widget && swift test 2>&1`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git -C /Users/aman/Documents/opencode-plugin add opencode-widget/Sources/OpencodeUsageTrackerApp/App.swift
git -C /Users/aman/Documents/opencode-plugin commit -m "feat: add app entry point and wire everything together"
```
