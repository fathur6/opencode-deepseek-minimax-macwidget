# Opencode Usage Widget Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS Notification Center Widget showing Deepseek/MiniMax balance and daily token usage.

**Architecture:** SwiftUI WidgetKit widget extension + companion app (LaunchAgent). Companion app fetches Deepseek balance via API and queries the local opencode SQLite DB, then writes aggregated data to a shared app group container. Widget reads from the shared container.

**Tech Stack:** Swift 5.9+, SwiftUI, WidgetKit, URLSession, SQLite3, LaunchAgent

## Global Constraints

- Deployment target: macOS 14+
- Xcode 15+ required for WidgetKit development
- Shared App Group container for cross-process data sharing
- API keys read from `~/.local/share/opencode/auth.json`
- SQLite database at `~/.local/share/opencode/opencode.db`
- No third-party dependencies (use Foundation, SQLite3 lib)

---

### Task 1: Project Scaffolding & Xcode Setup

**Files:**
- Create: `opencode-widget/OpencodeWidgetApp.xcodeproj/project.pbxproj`
- Create: `opencode-widget/OpencodeWidgetApp/Info.plist`
- Create: `opencode-widget/OpencodeWidget/Info.plist`
- Create: `opencode-widget/Shared/Bridge.h`

**Interfaces:**
- Produces: Xcode project with two targets: `OpencodeWidgetApp` (Cocoa App) and `OpencodeWidget` (Widget Extension)
- Produces: App Group entitlement `group.com.opencode.widget` for shared data

- [ ] **Step 1: Create project directory structure**

```bash
mkdir -p opencode-widget/OpencodeWidgetApp
mkdir -p opencode-widget/OpencodeWidget
mkdir -p opencode-widget/Shared
mkdir -p opencode-widget/Resources
```

- [ ] **Step 2: Create the project using Xcode CLI (or generate manually)**

Note: The project will be created via `xcodebuild` or manual Xcode project file generation. For the initial implementation, we'll use a Swift Package Manager approach with a custom Xcode project wrapper.

```bash
cd opencode-widget
swift package init --name OpencodeWidgetApp --type executable
```

- [ ] **Step 3: Set up Package.swift with iOS/macOS targets**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpencodeWidgetApp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "OpencodeWidgetApp",
            dependencies: [],
            resources: [.copy("Resources")]
        ),
        .target(
            name: "OpencodeWidget",
            dependencies: ["OpencodeWidgetApp"],
            resources: []
        ),
    ]
)
```

- [ ] **Step 4: Create shared App Group entitlement**

```xml
<!-- OpencodeWidgetApp/Entitlements.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
```

---

### Task 2: Shared Data Models

**Files:**
- Create: `opencode-widget/Shared/Models.swift`

**Interfaces:**
- Produces: `WidgetData`, `ProviderBalance`, `DailyUsageRow`, `WidgetCache` structs

- [ ] **Step 1: Write data model types**

```swift
import Foundation

public struct ProviderBalance: Codable, Equatable {
    public var balance: Double?
    public var currency: String

    public init(balance: Double? = nil, currency: String = "USD") {
        self.balance = balance
        self.currency = currency
    }
}

public struct DailyUsageRow: Codable, Identifiable, Equatable {
    public var id: String { date }
    public let date: String
    public var deepseekTokens: Int
    public var deepseekCost: Double
    public var minimaxTokens: Int
    public var minimaxCost: Double

    public init(date: String, deepseekTokens: Int = 0, deepseekCost: Double = 0, minimaxTokens: Int = 0, minimaxCost: Double = 0) {
        self.date = date
        self.deepseekTokens = deepseekTokens
        self.deepseekCost = deepseekCost
        self.minimaxTokens = minimaxTokens
        self.minimaxCost = minimaxCost
    }

    public var totalTokens: Int { deepseekTokens + minimaxTokens }
    public var totalCost: Double { deepseekCost + minimaxCost }
}

public struct WidgetCache: Codable {
    public let lastUpdated: Date
    public var deepseek: ProviderBalance
    public var minimax: ProviderBalance
    public var dailyUsage: [DailyUsageRow]

    public init(lastUpdated: Date = Date(), deepseek: ProviderBalance = ProviderBalance(), minimax: ProviderBalance = ProviderBalance(), dailyUsage: [DailyUsageRow] = []) {
        self.lastUpdated = lastUpdated
        self.deepseek = deepseek
        self.minimax = minimax
        self.dailyUsage = dailyUsage
    }

    public var isEmpty: Bool {
        dailyUsage.isEmpty && deepseek.balance == nil && minimax.balance == nil
    }
}
```

---

### Task 3: Auth Reader — Read Opencode Credentials

**Files:**
- Create: `opencode-widget/OpencodeWidgetApp/AuthReader.swift`

**Interfaces:**
- Produces: `AuthReader.readCredentials() -> (deepseekKey: String, minimaxKey: String)?`

- [ ] **Step 1: Write AuthReader**

```swift
import Foundation

struct AuthCredentials {
    let deepseekKey: String
    let minimaxKey: String
}

enum AuthReader {
    static let authPath = "\(NSHomeDirectory())/.local/share/opencode/auth.json"

    static func readCredentials() -> AuthCredentials? {
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
}
```

---

### Task 4: Data Fetcher — API Calls & DB Queries

**Files:**
- Create: `opencode-widget/OpencodeWidgetApp/DataFetcher.swift`

**Interfaces:**
- Consumes: `AuthCredentials`, `WidgetCache`, `DailyUsageRow`
- Produces: `DataFetcher.fetchDeepseekBalance(apiKey:) -> Double?`
- Produces: `DataFetcher.queryUsageFromDB() -> [DailyUsageRow]`
- Produces: `DataFetcher.refreshAll() async -> WidgetCache`

- [ ] **Step 1: Write Deepseek balance API fetch**

```swift
import Foundation

enum DataFetcher {
    static let deepseekBalanceURL = URL(string: "https://api.deepseek.com/user/balance")!
    static let dbPath = "\(NSHomeDirectory())/.local/share/opencode/opencode.db"

    static func fetchDeepseekBalance(apiKey: String) async -> Double? {
        var request = URLRequest(url: deepseekBalanceURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        guard let data = try? await URLSession.shared.data(for: request).0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let infos = json["balance_infos"] as? [[String: Any]],
              let first = infos.first,
              let balanceStr = first["total_balance"] as? String,
              let balance = Double(balanceStr) else {
            return nil
        }
        return balance
    }
}
```

- [ ] **Step 2: Write opencode DB query**

```swift
import SQLite3

extension DataFetcher {
    static func queryUsageFromDB() -> [DailyUsageRow] {
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
          AND time_created > strftime('%s', 'now', '-6 days')
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
            let day = String(cString: sqlite3_column_text(statement, 0))
            let provider = String(cString: sqlite3_column_text(statement, 1))
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
}
```

- [ ] **Step 3: Write refreshAll coordinator**

```swift
extension DataFetcher {
    static func refreshAll() async -> WidgetCache {
        guard let creds = AuthReader.readCredentials() else {
            return WidgetCache(
                lastUpdated: Date(),
                deepseek: ProviderBalance(balance: nil, currency: "USD"),
                minimax: ProviderBalance(balance: nil, currency: "USD"),
                dailyUsage: queryUsageFromDB()
            )
        }

        let deepseekBalance = await fetchDeepseekBalance(apiKey: creds.deepseekKey)
        let usage = queryUsageFromDB()

        return WidgetCache(
            lastUpdated: Date(),
            deepseek: ProviderBalance(balance: deepseekBalance, currency: "USD"),
            minimax: ProviderBalance(balance: nil, currency: "USD"),
            dailyUsage: usage
        )
    }
}
```

---

### Task 5: Data Store — Shared Cache Read/Write

**Files:**
- Create: `opencode-widget/OpencodeWidgetApp/DataStore.swift`

**Interfaces:**
- Consumes: `WidgetCache`
- Produces: `DataStore.save(cache:)`, `DataStore.load() -> WidgetCache?`
- Produces: `DataStore.sharedContainerURL: URL`

- [ ] **Step 1: Write DataStore with shared container support**

```swift
import Foundation

enum DataStore {
    static let suiteName = "group.com.opencode.widget"
    static let fileName = "widget-data.json"

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent(fileName)
    }

    static func save(cache: WidgetCache) {
        guard let url = sharedContainerURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cache) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> WidgetCache? {
        guard let url = sharedContainerURL,
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetCache.self, from: data)
    }
}
```

---

### Task 6: Widget Extension — Timeline Provider

**Files:**
- Create: `opencode-widget/OpencodeWidget/OpencodeWidget.swift`

**Interfaces:**
- Consumes: `WidgetCache`, `DataStore`
- Produces: Widget Timeline entries for WidgetKit

- [ ] **Step 1: Write TimelineEntry and Provider**

```swift
import WidgetKit
import SwiftUI

struct UsageEntry: TimelineEntry {
    let date: Date
    let cache: WidgetCache
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), cache: WidgetCache(lastUpdated: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let cache = DataStore.load() ?? WidgetCache(lastUpdated: Date())
        completion(UsageEntry(date: Date(), cache: cache))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let cache = DataStore.load() ?? WidgetCache(lastUpdated: Date())
        let entry = UsageEntry(date: Date(), cache: cache)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
```

- [ ] **Step 2: Write Widget configuration**

```swift
@main
struct OpencodeUsageWidget: Widget {
    let kind: String = "OpencodeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("AI Platform Usage")
        .description("Deepseek and MiniMax balance & token usage")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
```

---

### Task 7: Widget Extension — UI Views

**Files:**
- Create: `opencode-widget/OpencodeWidget/WidgetView.swift`
- Create: `opencode-widget/OpencodeWidget/BalanceCardView.swift`
- Create: `opencode-widget/OpencodeWidget/UsageChartView.swift`
- Create: `opencode-widget/OpencodeWidget/CostFooterView.swift`

**Interfaces:**
- Consumes: `UsageEntry`, `WidgetCache`, `DailyUsageRow`
- Produces: SwiftUI views for widget display

- [ ] **Step 1: Write BalanceCardView**

```swift
import SwiftUI

struct BalanceCardView: View {
    let title: String
    let balance: Double?
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            if let balance {
                Text(String(format: "$%.2f", balance))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            } else {
                Text("Set in Prefs")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
```

- [ ] **Step 2: Write UsageChartView (simplified bar chart)**

```swift
struct UsageChartView: View {
    let dailyUsage: [DailyUsageRow]

    private var maxTokens: Int {
        dailyUsage.map(\.totalTokens).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daily Token Usage (5 days)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(dailyUsage.suffix(5)) { row in
                    VStack(spacing: 2) {
                        let deepHeight = maxTokens > 0 ? CGFloat(row.deepseekTokens) / CGFloat(maxTokens) * 60 : 0
                        let miniHeight = maxTokens > 0 ? CGFloat(row.minimaxTokens) / CGFloat(maxTokens) * 60 : 0

                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.green.opacity(0.7))
                                .frame(height: max(miniHeight, 2))
                            Rectangle()
                                .fill(Color.blue.opacity(0.7))
                                .frame(height: max(deepHeight, 2))
                        }
                        .frame(width: 36)
                        .cornerRadius(3)

                        Text(formatDate(row.date))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 70)
        }
    }

    private func formatDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count >= 3 else { return date }
        return "\(parts[1])/\(parts[2])"
    }
}
```

- [ ] **Step 3: Write CostFooterView**

```swift
struct CostFooterView: View {
    let dailyUsage: [DailyUsageRow]

    private var todayCost: Double { dailyUsage.last?.totalCost ?? 0 }
    private var weekCost: Double { dailyUsage.reduce(0) { $0 + $1.totalCost } }

    var body: some View {
        HStack {
            Label(String(format: "Today: $%.2f", todayCost), systemImage: "arrow.up.circle")
            Spacer()
            Label(String(format: "7-day: $%.2f", weekCost), systemImage: "clock")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}
```

- [ ] **Step 4: Write main WidgetView**

```swift
struct WidgetView: View {
    var entry: UsageEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.accentColor)
                Text("AI Platform Usage")
                    .font(.headline)
                Spacer()
                Text(entry.cache.lastUpdated, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                BalanceCardView(
                    title: "Deepseek",
                    balance: entry.cache.deepseek.balance,
                    color: .blue
                )
                BalanceCardView(
                    title: "MiniMax",
                    balance: entry.cache.minimax.balance,
                    color: .green
                )
            }

            if !entry.cache.dailyUsage.isEmpty {
                UsageChartView(dailyUsage: entry.cache.dailyUsage)
                CostFooterView(dailyUsage: entry.cache.dailyUsage)
            } else {
                Text("No usage data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
```

---

### Task 8: Companion App — Preferences Window

**Files:**
- Modify: `opencode-widget/OpencodeWidgetApp/ContentView.swift`
- Create: `opencode-widget/OpencodeWidgetApp/PreferencesView.swift`

**Interfaces:**
- Consumes: `WidgetCache`, `DataStore`, `DataFetcher`
- Produces: Preferences UI for MiniMax manual balance entry + manual refresh button

- [ ] **Step 1: Write PreferencesView**

```swift
import SwiftUI

struct PreferencesView: View {
    @AppStorage("minimaxBalance", store: UserDefaults(suiteName: "group.com.opencode.widget"))
    private var minimaxBalance: String = ""

    @State private var refreshStatus = ""

    var body: some View {
        Form {
            Section("MiniMax Balance") {
                TextField("Enter balance (e.g. 5.00)", text: $minimaxBalance)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: minimaxBalance) { _ in
                        updateWidgetCache()
                    }
            }

            Section("Deepseek") {
                Text("Auto-fetched from API")
                    .foregroundColor(.secondary)
            }

            Section {
                Button("Refresh Now") {
                    Task {
                        refreshStatus = "Refreshing..."
                        let cache = await DataFetcher.refreshAll()
                        DataStore.save(cache: cache)
                        refreshStatus = "Updated at \(Date().formatted(date: .omitted, time: .shortened))"
                    }
                }

                if !refreshStatus.isEmpty {
                    Text(refreshStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 320, height: 260)
    }

    private func updateWidgetCache() {
        var cache = DataStore.load() ?? WidgetCache(lastUpdated: Date())
        let balance = Double(minimaxBalance.replacingOccurrences(of: "$", with: ""))
        cache.minimax = ProviderBalance(balance: balance, currency: "USD")
        cache.lastUpdated = Date()
        DataStore.save(cache: cache)
    }
}
```

- [ ] **Step 2: Write ContentView (menu bar with preferences)**

```swift
import SwiftUI

struct ContentView: View {
    @State private var showPreferences = false

    var body: some View {
        VStack {
            Button("Preferences...") {
                showPreferences.toggle()
            }
            Button("Refresh Widget Data") {
                Task {
                    let cache = await DataFetcher.refreshAll()
                    DataStore.save(cache: cache)
                }
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
    }
}
```

---

### Task 9: Companion App — App Entry Point & Lifecycle

**Files:**
- Create: `opencode-widget/OpencodeWidgetApp/OpencodeWidgetApp.swift`
- Create: `opencode-widget/Resources/LaunchAgent.plist`

**Interfaces:**
- Produces: Main app executable
- Produces: LaunchAgent plist for auto-start

- [ ] **Step 1: Write App entry point**

```swift
import SwiftUI

@main
struct OpencodeWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Opencode Widget", systemImage: "chart.bar.fill") {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            let cache = await DataFetcher.refreshAll()
            DataStore.save(cache: cache)
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { _ in
            Task {
                let cache = await DataFetcher.refreshAll()
                DataStore.save(cache: cache)
            }
        }
    }
}
```

- [ ] **Step 2: Write LaunchAgent plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.opencode.widget.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/OpencodeWidgetApp.app/Contents/MacOS/OpencodeWidgetApp</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StartInterval</key>
    <integer>900</integer>
</dict>
</plist>
```

---

### Task 10: Wire Everything Together

**Files:**
- Modify: `opencode-widget/Package.swift` (finalize with all targets)

- [ ] **Step 1: Update Package.swift with all targets and dependencies**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpencodeWidgetApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Shared", targets: ["Shared"]),
    ],
    targets: [
        .target(
            name: "Shared",
            path: "Shared"
        ),
        .executableTarget(
            name: "OpencodeWidgetApp",
            dependencies: ["Shared"],
            path: "OpencodeWidgetApp",
            resources: [
                .copy("../Resources/LaunchAgent.plist")
            ]
        ),
        .target(
            name: "OpencodeWidget",
            dependencies: ["Shared"],
            path: "OpencodeWidget"
        ),
    ]
)
```

- [ ] **Step 2: Create build script**

```bash
#!/bin/bash
# build.sh — Build the project
cd "$(dirname "$0")"
swift build
echo "Build complete. Binary at .build/debug/OpencodeWidgetApp"
```

- [ ] **Step 3: Create install script for LaunchAgent**

```bash
#!/bin/bash
# install-launch-agent.sh
cp Resources/LaunchAgent.plist ~/Library/LaunchAgents/com.opencode.widget.agent.plist
launchctl load ~/Library/LaunchAgents/com.opencode.widget.agent.plist
echo "LaunchAgent installed and loaded."
```
