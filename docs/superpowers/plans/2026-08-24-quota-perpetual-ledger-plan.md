# Perpetual 12-Month Quota Ledger, Archive & Month-End Email Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a durable 12-month SQLite ledger of hourly DeepSeek-USD / OpenAI-% snapshots, plus a month-end (strictly last calendar day) report that emails a summary + embedded CSV to fathur6@gmail.com and archives the CSV permanently.

**Architecture:** A new Swift library target `OpencodeWidgetLedger` (links `sqlite3`) holds `QuotaLedger` (append-only upsert + 12-month prune), `QuotaMonthlyReporter` (last-day gate + CSV/summary build), and a `QuotaEmailSending` protocol with a default that shells out to the existing Hermes Gmail script. `OpencodeWidgetApp` depends on it; capture is hooked into `DataFetcher.refreshAll`. Display arrays stay unchanged.

**Tech Stack:** Swift 6.3, SQLite3 (linked), Foundation, XCTest, Swift Package Manager, Hermes `google_api.py` for email.

## Global Constraints

- Ledger table: `quota_snapshots(hour TEXT PRIMARY KEY, deepseek_usd REAL, openai_percent REAL, source TEXT, recorded_at TEXT)` and `quota_month_mark(yyyy_mm TEXT PRIMARY KEY, emailed_at TEXT)`.
- Ledger path: `~/Library/Application Support/OpencodeWidgetApp/quota.db`; archive dir `~/Library/Application Support/OpencodeWidgetApp/archive/`.
- Retention: prune removes `hour < startOfMonth(now) − 12 months`; exactly 12 months kept.
- Upsert-by-hour: last observation in an hour wins (matches existing `DeepSeekBalanceHistory`/`OpenAIQuotaHistory` semantics).
- Month-end email fires only when: today is the last calendar day of the month AND current `YYYY-MM` not already emailed.
- Email recipient: `fathur6@gmail.com`. Subject: `OpenCode widget quota report — <Month Year>`.
- Email body = summary paragraph + the month's CSV rows as plain text (no attachment support in the Hermes script).
- CSV columns: `hour,deepseek_usd,openai_percent,source`.
- Email via `python3 ~/.hermes/skills/productivity/google-workspace/scripts/google_api.py gmail send --to <to> --subject "<subject>" --body "<body>"`; success = exit 0.
- Order: email → write archive CSV → mark month emailed. On email failure: do NOT archive or mark (retry later). Empty month: no-op.
- First-run back-fill: import `WidgetCache.deepseekBalanceHistory` (→ `deepseek_usd = remainingRM / usdToMYR`) and `WidgetCache.openAIQuotaHistory` (→ `openai_percent`) only when `quota_snapshots` is empty.
- `OpencodeWidgetShared` must NOT gain a sqlite3 dependency (left as-is).

---

### Task 1: Create the `OpencodeWidgetLedger` target and `QuotaLedger` types

**Files:**
- Modify: `opencode-widget/Package.swift`
- Create: `opencode-widget/Sources/OpencodeWidgetLedger/QuotaLedger.swift`
- Create: `opencode-widget/Sources/OpencodeWidgetLedger/QuotaSnapshotRow.swift`
- Test: `opencode-widget/Tests/OpencodeWidgetLedgerTests/QuotaLedgerTests.swift`

**Interfaces:**
- Produces:
  - `public struct QuotaSnapshotRow: Equatable, Sendable { public let hour: Date; public let deepseekUSD: Double?; public let openaiPercent: Double?; public let source: String }`
  - `public enum QuotaLedger { public static func open(path: String) -> QuotaLedgerHandle }` (or a class `QuotaLedgerAgent`; see code below for the concrete type)
  - `QuotaLedger.record(hour:deepseekUSD:openaiPercent:source:)`, `QuotaLedger.prune(retentionMonths:now:)`, `QuotaLedger.rows(from:to:) -> [QuotaSnapshotRow]`, `QuotaLedger.count() -> Int`, `QuotaLedger.markMonthEmailed(yyyyMM:)`, `QuotaLedger.isMonthEmailed(yyyyMM:) -> Bool`, `QuotaLedger.backfill(deepseek:openAI:)`, `QuotaLedger.monthRows(month: Date) -> [QuotaSnapshotRow]`.

**Target wiring (step keeps it compilable):**

- [ ] **Step 1: Write the failing tests**

Create `opencode-widget/Tests/OpencodeWidgetLedgerTests/QuotaLedgerTests.swift`:

```swift
import XCTest
import SQLite3
@testable import OpencodeWidgetLedger

final class QuotaLedgerTests: XCTestCase {
    var ledger: QuotaLedger!
    var dbPath: String!

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ledger-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dbPath = dir.appendingPathComponent("quota.db").path
        ledger = QuotaLedger.open(path: dbPath)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: dbPath)
        ledger = nil
        super.tearDown()
    }

    func testRecordUpsertsByHour() {
        let hour = Date(timeIntervalSince1970: 1_800_000_000)
        ledger.record(hour: hour, deepseekUSD: 10, openaiPercent: 44, source: "both")
        ledger.record(hour: hour, deepseekUSD: 9.5, openaiPercent: nil, source: "deepseek")

        let rows = ledger.monthRows(month: hour)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].deepseekUSD, 9.5)
        XCTAssertNil(rows[0].openaiPercent)
        XCTAssertEqual(rows[0].source, "deepseek")
    }

    func testRowsRangeFiltersByMonth() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        ledger.record(hour: start, deepseekUSD: 10, openaiPercent: 44, source: "both")
        ledger.record(hour: start.addingTimeInterval(40 * 24 * 3_600), deepseekUSD: 20, openaiPercent: 50, source: "both")

        let august = ledger.rows(from: start, to: start.addingTimeInterval(31 * 24 * 3_600))
        XCTAssertEqual(august.count, 1)
    }

    func testMonthMarkRoundTrip() {
        ledger.markMonthEmailed(yyyyMM: "2026-08")
        XCTAssertTrue(ledger.isMonthEmailed(yyyyMM: "2026-08"))
        XCTAssertFalse(ledger.isMonthEmailed(yyyyMM: "2026-09"))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd opencode-widget && swift test --filter QuotaLedgerTests`
Expected: FAIL — cannot find type `QuotaLedger` in scope (target not yet wired).

- [ ] **Step 3: Wire the target into Package.swift**

Edit `opencode-widget/Package.swift`:

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "OpencodeWidgetApp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(name: "OpencodeWidgetShared"),
        .target(
            name: "OpencodeWidgetLedger",
            dependencies: ["OpencodeWidgetShared"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "OpencodeWidgetApp",
            dependencies: ["OpencodeWidgetShared", "OpencodeWidgetLedger"],
            resources: [.copy("Resources")],
            linkerSettings: [.linkedLibrary("sqlite3")]
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
            name: "OpencodeWidgetLedgerTests",
            dependencies: ["OpencodeWidgetLedger", "OpencodeWidgetShared"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "OpencodeWidgetAppTests",
            dependencies: ["OpencodeWidgetApp", "OpencodeWidgetShared"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "OpencodeUsageTrackerAppTests",
            dependencies: ["OpencodeUsageTrackerApp", "OpencodeWidgetShared"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
    ]
)
```

- [ ] **Step 4: Implement the ledger and row types**

Create `opencode-widget/Sources/OpencodeWidgetLedger/QuotaSnapshotRow.swift`:

```swift
import Foundation

public struct QuotaSnapshotRow: Equatable, Sendable {
    public let hour: Date
    public let deepseekUSD: Double?
    public let openaiPercent: Double?
    public let source: String

    public init(hour: Date, deepseekUSD: Double?, openaiPercent: Double?, source: String) {
        self.hour = hour
        self.deepseekUSD = deepseekUSD
        self.openaiPercent = openaiPercent
        self.source = source
    }
}
```

Create `opencode-widget/Sources/OpencodeWidgetLedger/QuotaLedger.swift`:

```swift
import Foundation
import SQLite3

public final class QuotaLedger {
    private var db: OpaquePointer?

    public init(path: String) {
        var handle: OpaquePointer?
        if sqlite3_open(path, &handle) == SQLITE_OK, let handle {
            db = handle
            createSchema()
        } else {
            db = nil
        }
    }

    public static func open(path: String) -> QuotaLedger {
        QuotaLedger(path: path)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    private func createSchema() {
        guard let db else { return }
        let schema = """
        CREATE TABLE IF NOT EXISTS quota_snapshots(
          hour TEXT PRIMARY KEY,
          deepseek_usd REAL,
          openai_percent REAL,
          source TEXT,
          recorded_at TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_quota_snapshots_hour ON quota_snapshots(hour);
        CREATE TABLE IF NOT EXISTS quota_month_mark(
          yyyy_mm TEXT PRIMARY KEY,
          emailed_at TEXT
        );
        """
        sqlite3_exec(db, schema, nil, nil, nil)
    }

    private func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func isoFromString(_ s: String) -> Date? {
        ISO8601DateFormatter().date(from: s)
    }

    private func flooredHour(_ date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 3_600) * 3_600)
    }

    public func record(hour: Date, deepseekUSD: Double?, openaiPercent: Double?, source: String) {
        guard let db else { return }
        let h = flooredHour(hour)
        let sql = """
        INSERT INTO quota_snapshots(hour, deepseek_usd, openai_percent, source, recorded_at)
        VALUES(?, ?, ?, ?, ?)
        ON CONFLICT(hour) DO UPDATE SET
          deepseek_usd = excluded.deepseek_usd,
          openai_percent = excluded.openai_percent,
          source = excluded.source,
          recorded_at = excluded.recorded_at
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, iso(h), -1, nil)
        if let d = deepseekUSD {
            sqlite3_bind_double(stmt, 2, d)
        } else {
            sqlite3_bind_null(stmt, 2)
        }
        if let p = openaiPercent {
            sqlite3_bind_double(stmt, 3, p)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        sqlite3_bind_text(stmt, 4, source, -1, nil)
        sqlite3_bind_text(stmt, 5, iso(Date()), -1, nil)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    public func prune(retentionMonths: Int = 12, now: Date = Date()) {
        guard let db else { return }
        var comp = DateComponents()
        comp.month = -retentionMonths
        guard let cutoff = Calendar.current.date(byAdding: comp, to: now) else { return }
        let startOfCutoffMonth = Calendar.current.dateInterval(of: .month, for: cutoff)?.start ?? cutoff
        let sql = "DELETE FROM quota_snapshots WHERE hour < ?"
        let cutoffStr = iso(startOfCutoffMonth)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, cutoffStr, -1, nil)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    public func rows(from: Date, to: Date) -> [QuotaSnapshotRow] {
        guard let db else { return [] }
        let sql = "SELECT hour, deepseek_usd, openai_percent, source FROM quota_snapshots WHERE hour >= ? AND hour < ? ORDER BY hour ASC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        sqlite3_bind_text(stmt, 1, iso(from), -1, nil)
        sqlite3_bind_text(stmt, 2, iso(to), -1, nil)
        var result: [QuotaSnapshotRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let hptr = sqlite3_column_text(stmt, 0), let hstr = String(cString: hptr, encoding: .utf8), let h = isoFromString(hstr) else { continue }
            let d: Double? = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 1)
            let p: Double? = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 2)
            let src = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? "" : String(cString: sqlite3_column_text(stmt, 3))
            result.append(QuotaSnapshotRow(hour: h, deepseekUSD: d, openaiPercent: p, source: src))
        }
        sqlite3_finalize(stmt)
        return result
    }

    public func monthRows(month: Date) -> [QuotaSnapshotRow] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: month) else { return [] }
        return rows(from: interval.start, to: interval.end)
    }

    public func count() -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM quota_snapshots", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        var n = 0
        if sqlite3_step(stmt) == SQLITE_ROW { n = Int(sqlite3_column_int64(stmt, 0)) }
        sqlite3_finalize(stmt)
        return n
    }

    public func markMonthEmailed(yyyyMM: String) {
        guard let db else { return }
        let sql = "INSERT INTO quota_month_mark(yyyy_mm, emailed_at) VALUES(?, ?) ON CONFLICT(yyyy_mm) DO UPDATE SET emailed_at = excluded.emailed_at"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, yyyyMM, -1, nil)
        sqlite3_bind_text(stmt, 2, iso(Date()), -1, nil)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    public func isMonthEmailed(yyyyMM: String) -> Bool {
        guard let db else { return false }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM quota_month_mark WHERE yyyy_mm = ?", -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_text(stmt, 1, yyyyMM, -1, nil)
        let found = sqlite3_step(stmt) == SQLITE_ROW
        sqlite3_finalize(stmt)
        return found
    }

    public func backfill(deepseek: [DeepSeekBalanceSnapshot], openAI: [OpenAIQuotaSnapshot]) {
        guard count() == 0 else { return }
        for snap in deepseek {
            record(hour: snap.hour, deepseekUSD: snap.remainingRM / DeepSeekBalanceHistory.usdToMYR, openaiPercent: nil, source: "deepseek")
        }
        for snap in openAI {
            record(hour: snap.hour, deepseekUSD: nil, openaiPercent: snap.remainingPercent, source: "openai")
        }
    }
}
```

Note: `backfill` merges DeepSeek and OpenAI rows by hour. If the same hour has both, the second `record` call for that hour overwrites the first. To preserve both, we should merge before recording. See Step 5 for the correct merged backfill — implement that instead of the simple loop above.

- [ ] **Step 5: Fix backfill to merge both series per hour**

Replace the `backfill` body with a merge that keeps both columns per hour:

```swift
    public func backfill(deepseek: [DeepSeekBalanceSnapshot], openAI: [OpenAIQuotaSnapshot]) {
        guard count() == 0 else { return }
        let dsByHour = Dictionary(uniqueKeysWithValues: deepseek.map { (flooredHour($0.hour), $0.remainingRM / DeepSeekBalanceHistory.usdToMYR) })
        let oaByHour = Dictionary(uniqueKeysWithValues: openAI.map { (flooredHour($0.hour), $0.remainingPercent) })
        let allHours = Set(dsByHour.keys).union(oaByHour.keys).sorted()
        for hour in allHours {
            let d = dsByHour[hour]
            let p = oaByHour[hour]
            let source: String
            switch (d, p) {
            case (nil, nil): continue
            case let (d?, nil): source = "deepseek"
            case let (nil, p?): source = "openai"
            case (.some, .some): source = "both"
            }
            record(hour: hour, deepseekUSD: d, openaiPercent: p, source: source)
        }
    }
```

- [ ] **Step 6: Run tests to verify pass**

Run: `cd opencode-widget && swift test --filter QuotaLedgerTests`
Expected: PASS (3 tests).

Add a prune test before committing (Step 7). Update `QuotaLedgerTests` to add:

```swift
    func testPruneKeepsTwelveMonths() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = Calendar.current.date(byAdding: .month, value: -13, to: now)!
        ledger.record(hour: old, deepseekUSD: 1, openaiPercent: nil, source: "deepseek")
        ledger.record(hour: now, deepseekUSD: 2, openaiPercent: nil, source: "deepseek")
        ledger.prune(retentionMonths: 12, now: now)
        let all = ledger.rows(from: Date(timeIntervalSince1970: 0), to: Date(timeIntervalSince1970: 4_000_000_000))
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].deepseekUSD, 2)
    }
```

- [ ] **Step 7: Run and commit**

Run: `cd opencode-widget && swift test --filter QuotaLedgerTests`
Expected: PASS (4 tests).

```bash
git add opencode-widget/Package.swift opencode-widget/Sources/OpencodeWidgetLedger/ opencode-widget/Tests/OpencodeWidgetLedgerTests/
git commit -m "feat: add quota ledger with 12-month retention"
```

---

### Task 2: Monthly reporter (CSV, summary, last-day gate)

**Files:**
- Create: `opencode-widget/Sources/OpencodeWidgetLedger/QuotaMonthlyReporter.swift`
- Create: `opencode-widget/Tests/OpencodeWidgetLedgerTests/QuotaMonthlyReporterTests.swift`

**Interfaces:**
- Consumes: `QuotaLedger` API from Task 1, `QuotaEmailSending` protocol (defined here).
- Produces:
  - `public protocol QuotaEmailSending { func sendQuotaReport(subject: String, body: String, to: String) async -> Bool }`
  - `public struct QuotaMonthlySummary: Equatable { public let daysWithData: Int; public let daysWithGap: Int; public let topUpCount: Int; public let avgDeepseekUSD: Double?; public let avgOpenaiPercent: Double? }`
  - `public enum QuotaReportFormatter { public static func isLastCalendarDay(of date: Date, calendar: Calendar = .current) -> Bool; public static func yyyyMM(_ month: Date, calendar: Calendar = .current) -> String; public static func monthTitle(_ month: Date) -> String; public static func csv(rows: [QuotaSnapshotRow]) -> String; public static func summaryText(summary: QuotaMonthlySummary) -> String; public static func summary(from: [QuotaSnapshotRow]) -> QuotaMonthlySummary; public static func emailBody(summary: QuotaMonthlySummary, rows: [QuotaSnapshotRow]) -> String }`
  - `public class QuotaMonthlyReporter { public init(ledger: QuotaLedger, sender: QuotaEmailSending, to: String, now: @escaping () -> Date) ; @discardableResult public func runIfDue() async -> Bool }`

- [ ] **Step 1: Write failing tests**

Create `opencode-widget/Tests/OpencodeWidgetLedgerTests/QuotaMonthlyReporterTests.swift`:

```swift
import XCTest
@testable import OpencodeWidgetLedger

final class QuotaMonthlyReporterTests: XCTestCase {
    private var ledger: QuotaLedger!
    private var dbPath: String!

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mrep-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dbPath = dir.appendingPathComponent("quota.db").path
        ledger = QuotaLedger.open(path: dbPath)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: dbPath)
        ledger = nil
        super.tearDown()
    }

    final class FakeSender: QuotaEmailSending {
        var calls: [(subject: String, body: String, to: String)] = []
        var result = true
        func sendQuotaReport(subject: String, body: String, to: String) async -> Bool {
            calls.append((subject, body, to))
            return result
        }
    }

    func testNotLastDayDoesNothing() async {
        // 2026-08-15 is NOT the last day
        let notLast = isoDate(2026, 8, 15)
        let sender = FakeSender()
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { notLast })
        let sent = await reporter.runIfDue()
        XCTAssertFalse(sent)
        XCTAssertEqual(sender.calls.count, 0)
    }

    func testLastDaySendsSummaryAndCSV() async {
        // 2026-08-31 is the last day of August
        let last = isoDate(2026, 8, 31)
        let aug1 = isoDate(2026, 8, 1)
        ledger.record(hour: aug1, deepseekUSD: 10, openaiPercent: 50, source: "both")
        let sender = FakeSender()
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { last })
        let sent = await reporter.runIfDue()
        XCTAssertTrue(sent)
        XCTAssertEqual(sender.calls.count, 1)
        XCTAssertEqual(sender.calls[0].to, "fathur6@gmail.com")
        XCTAssertTrue(sender.calls[0].subject.contains("2026"))
        XCTAssertTrue(sender.calls[0].body.contains("hour,deepseek_usd,openai_percent,source"))
        XCTAssertTrue(sender.calls[0].body.contains("10"))
        XCTAssertTrue(ledger.isMonthEmailed(yyyyMM: "2026-08"))
    }

    func testLastDayIdempotent() async {
        let last = isoDate(2026, 8, 31)
        let aug1 = isoDate(2026, 8, 1)
        ledger.record(hour: aug1, deepseekUSD: 10, openaiPercent: 50, source: "both")
        let sender = FakeSender()
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { last })
        _ = await reporter.runIfDue()
        let second = await reporter.runIfDue()
        XCTAssertFalse(second)
        XCTAssertEqual(sender.calls.count, 1)
    }

    func testEmptyMonthDoesNothing() async {
        let last = isoDate(2026, 8, 31)
        let sender = FakeSender()
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { last })
        let sent = await reporter.runIfDue()
        XCTAssertFalse(sent)
        XCTAssertEqual(sender.calls.count, 0)
        XCTAssertFalse(ledger.isMonthEmailed(yyyyMM: "2026-08"))
    }

    func testSendFailureDoesNotArchiveOrMark() async {
        let last = isoDate(2026, 8, 31)
        let aug1 = isoDate(2026, 8, 1)
        ledger.record(hour: aug1, deepseekUSD: 10, openaiPercent: 50, source: "both")
        let sender = FakeSender()
        sender.result = false
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { last })
        let sent = await reporter.runIfDue()
        XCTAssertFalse(sent)
        XCTAssertFalse(ledger.isMonthEmailed(yyyyMM: "2026-08"))
    }

    func testWritesArchiveWhenDirProvided() async {
        let last = isoDate(2026, 8, 31)
        let aug1 = isoDate(2026, 8, 1)
        ledger.record(hour: aug1, deepseekUSD: 10, openaiPercent: 50, source: "both")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("archive-\(UUID().uuidString)").path
        let sender = FakeSender()
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { last }, archiveDir: dir)
        let sent = await reporter.runIfDue()
        XCTAssertTrue(sent)
        let file = URL(fileURLWithPath: dir).appendingPathComponent("quota-2026-08.csv")
        let exists = FileManager.default.fileExists(atPath: file.path)
        XCTAssertTrue(exists)
        let content = try? String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(content?.contains("hour,deepseek_usd,openai_percent,source") ?? false)
    }

    private func isoDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comp = DateComponents()
        comp.year = y; comp.month = m; comp.day = d; comp.hour = 12
        return Calendar.current.date(from: comp)!
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd opencode-widget && swift test --filter QuotaMonthlyReporterTests`
Expected: FAIL — `QuotaMonthlyReporter` and `QuotaEmailSending` undefined.

- [ ] **Step 3: Implement the reporter and formatter**

Create `opencode-widget/Sources/OpencodeWidgetLedger/QuotaMonthlyReporter.swift`:

```swift
import Foundation

public protocol QuotaEmailSending {
    func sendQuotaReport(subject: String, body: String, to: String) async -> Bool
}

public struct QuotaMonthlySummary: Equatable {
    public let daysWithData: Int
    public let daysWithGap: Int
    public let topUpCount: Int
    public let avgDeepseekUSD: Double?
    public let avgOpenaiPercent: Double?

    public init(daysWithData: Int, daysWithGap: Int, topUpCount: Int, avgDeepseekUSD: Double?, avgOpenaiPercent: Double?) {
        self.daysWithData = daysWithData
        self.daysWithGap = daysWithGap
        self.topUpCount = topUpCount
        self.avgDeepseekUSD = avgDeepseekUSD
        self.avgOpenaiPercent = avgOpenaiPercent
    }
}

public enum QuotaReportFormatter {
    public static func isLastCalendarDay(of date: Date, calendar: Calendar = .current) -> Bool {
        guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { return false }
        return !calendar.isDate(date, equalTo: next, toGranularity: .month)
    }

    public static func yyyyMM(_ month: Date, calendar: Calendar = .current) -> String {
        let comp = calendar.dateComponents([.year, .month], from: month)
        return String(format: "%04d-%02d", comp.year ?? 0, comp.month ?? 0)
    }

    public static func monthTitle(_ month: Date) -> String {
        month.formatted(.dateTime.month(.wide).year())
    }

    public static func csv(rows: [QuotaSnapshotRow]) -> String {
        var out = "hour,deepseek_usd,openai_percent,source\n"
        let iso = ISO8601DateFormatter()
        for r in rows {
            let d = r.deepseekUSD.map(String.init) ?? ""
            let p = r.openaiPercent.map(String.init) ?? ""
            out += "\(iso.string(from: r.hour)),\(d),\(p),\(r.source)\n"
        }
        return out
    }

    public static func summary(from rows: [QuotaSnapshotRow]) -> QuotaMonthlySummary {
        let dsValues = rows.compactMap(\.deepseekUSD)
        let oaValues = rows.compactMap(\.openaiPercent)
        let days = Set(rows.map { Calendar.current.startOfDay(for: $0.hour) })
        var topUps = 0
        let ordered = rows.sorted { $0.hour < $1.hour }
        var prev: Double?
        for r in ordered {
            if let d = r.deepseekUSD, let p = prev, d > p { topUps += 1 }
            if r.deepseekUSD != nil { prev = r.deepseekUSD }
        }
        let daysWithData = days.count
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: rows.first?.hour ?? Date())?.count ?? 30
        return QuotaMonthlySummary(
            daysWithData: daysWithData,
            daysWithGap: max(0, daysInMonth - daysWithData),
            topUpCount: topUps,
            avgDeepseekUSD: dsValues.isEmpty ? nil : dsValues.reduce(0, +) / Double(dsValues.count),
            avgOpenaiPercent: oaValues.isEmpty ? nil : oaValues.reduce(0, +) / Double(oaValues.count)
        )
    }

    public static func summaryText(summary: QuotaMonthlySummary) -> String {
        let ds = summary.avgDeepseekUSD.map { String(format: "$%.2f", $0) } ?? "n/a"
        let oa = summary.avgOpenaiPercent.map { String(format: "%.1f%%", $0) } ?? "n/a"
        return """
        Days with data: \(summary.daysWithData)
        Days with gaps: \(summary.daysWithGap)
        Top-ups: \(summary.topUpCount)
        Avg DeepSeek balance: \(ds)
        Avg OpenAI remaining: \(oa)
        """
    }

    public static func emailBody(summary: QuotaMonthlySummary, rows: [QuotaSnapshotRow]) -> String {
        "Monthly quota report\n\n" + summaryText(summary: summary) + "\n\n---\n" + csv(rows: rows)
    }
}

public class QuotaMonthlyReporter {
    private let ledger: QuotaLedger
    private let sender: QuotaEmailSending
    private let to: String
    private let now: () -> Date
    private let calendar: Calendar
    private let archiveDir: String?

    public init(ledger: QuotaLedger, sender: QuotaEmailSending, to: String, now: @escaping () -> Date, calendar: Calendar = .current, archiveDir: String? = nil) {
        self.ledger = ledger
        self.sender = sender
        self.to = to
        self.now = now
        self.calendar = calendar
        self.archiveDir = archiveDir
    }

    @discardableResult
    public func runIfDue() async -> Bool {
        let today = now()
        guard QuotaReportFormatter.isLastCalendarDay(of: today, calendar: calendar) else { return false }
        let yyyyMM = QuotaReportFormatter.yyyyMM(today, calendar: calendar)
        guard !ledger.isMonthEmailed(yyyyMM: yyyyMM) else { return false }
        let rows = ledger.monthRows(month: today)
        guard !rows.isEmpty else { return false }
        let summary = QuotaReportFormatter.summary(from: rows)
        let csv = QuotaReportFormatter.csv(rows: rows)
        let subject = "OpenCode widget quota report — \(QuotaReportFormatter.monthTitle(today))"
        let body = QuotaReportFormatter.emailBody(summary: summary, rows: rows)
        let ok = await sender.sendQuotaReport(subject: subject, body: body, to: to)
        if ok {
            ledger.markMonthEmailed(yyyyMM: yyyyMM)
            if let archiveDir {
                let dir = URL(fileURLWithPath: archiveDir, isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let file = dir.appendingPathComponent("quota-\(yyyyMM).csv")
                try? csv.data(using: .utf8)?.write(to: file, options: .atomic)
            }
        }
        return ok
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd opencode-widget && swift test --filter QuotaMonthlyReporterTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add opencode-widget/Sources/OpencodeWidgetLedger/QuotaMonthlyReporter.swift opencode-widget/Tests/OpencodeWidgetLedgerTests/
git commit -m "feat: add month-end quota reporter with summary + CSV"
```

---

### Task 3: Wire capture, back-fill, and the reporter into the app

**Files:**
- Modify: `opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift`
- Modify: `opencode-widget/Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift`
- Create: `opencode-widget/Sources/OpencodeWidgetApp/QuotaLedgerService.swift`
- Test: `opencode-widget/Tests/OpencodeWidgetAppTests/QuotaLedgerServiceTests.swift`

**Interfaces:**
- Consumes: `QuotaLedger`, `QuotaMonthlyReporter`, `QuotaEmailSending` from Tasks 1–2; `DeepSeekBalanceHistory.usdToMYR`.
- Produces: `QuotaLedgerService` singleton used by the app refresh paths.

- [ ] **Step 1: Write failing test for the service**

Create `opencode-widget/Tests/OpencodeWidgetAppTests/QuotaLedgerServiceTests.swift`:

```swift
import XCTest
@testable import OpencodeWidgetApp
@testable import OpencodeWidgetLedger

final class QuotaLedgerServiceTests: XCTestCase {
    func testOpenCreatesLedger() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("qs-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("quota.db").path
        let service = QuotaLedgerService(ledgerPath: path)
        XCTAssertNotNil(service.ledger)
        _ = service.ledger.count() // should not throw
    }
}
```

- [ ] **Step 2: Verify failure**

Run: `cd opencode-widget && swift test --filter QuotaLedgerServiceTests`
Expected: FAIL — `QuotaLedgerService` undefined.

- [ ] **Step 3: Implement the service**

Create `opencode-widget/Sources/OpencodeWidgetApp/QuotaLedgerService.swift`:

```swift
import Foundation
import OpencodeWidgetLedger
import OpencodeWidgetShared

final class QuotaLedgerService {
    static let shared = QuotaLedgerService()

    let ledger: QuotaLedger
    private let reporter: QuotaMonthlyReporter
    private let to = "fathur6@gmail.com"

    init(ledgerPath: String? = nil) {
        let fm = FileManager.default
        let base = ledgerPath ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OpencodeWidgetApp", isDirectory: true).path
        try? fm.createDirectory(atPath: base, withIntermediateDirectories: true)
        let dbPath = ledgerPath ?? "\(base)/quota.db"
        let ledger = QuotaLedger.open(path: dbPath)
        let sender = ProcessQuotaEmailSender()
        let archiveDir = "\(base)/archive"
        self.ledger = ledger
        self.reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: to, now: { Date() }, archiveDir: archiveDir)
    }

    func begin(of cache: WidgetCache) {
        ledger.backfill(deepseek: cache.deepseekBalanceHistory, openAI: cache.openAIQuotaHistory)
        ledger.prune(retentionMonths: 12)
    }

    func recordRefresh(cache: WidgetCache) {
        // back-fill once on the first non-empty cache
        if ledger.count() == 0 { begin(of: cache) }
        let now = Date()
        let dsUSD = currentDeepseekUSD(from: cache)
        let oaPercent = cache.openAIQuota?.remainingPercent
        guard dsUSD != nil || oaPercent != nil else { return }
        ledger.record(hour: now, deepseekUSD: dsUSD, openaiPercent: oaPercent, source: sourceLabel(ds: dsUSD, oa: oaPercent))
        ledger.prune(retentionMonths: 12)
    }

    func runMonthlyReportIfDue() async {
        _ = await reporter.runIfDue()
    }

    private func currentDeepseekUSD(from cache: WidgetCache) -> Double? {
        cache.deepseek.balance
    }

    private func sourceLabel(ds: Double?, oa: Double?) -> String {
        switch (ds, oa) {
        case (.some, .some): return "both"
        case (.some, nil): return "deepseek"
        case (nil, .some): return "openai"
        case (nil, nil): return ""
        }
    }
}
```

Note: `DeepSeekBalanceHistory.usdToMYR` is in `OpencodeWidgetShared`; confirm the service imports it (`import OpencodeWidgetShared`). Add `import OpencodeWidgetShared` to `QuotaLedgerService.swift`.

Also create the `ProcessQuotaEmailSender` in this file (or a separate file) implementing `QuotaEmailSending`:

```swift
import OpencodeWidgetLedger

struct ProcessQuotaEmailSender: QuotaEmailSending {
    let script = "\(NSHomeDirectory())/.hermes/skills/productivity/google-workspace/scripts/google_api.py"

    func sendQuotaReport(subject: String, body: String, to: String) async -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        p.arguments = [
            script,
            "gmail", "send",
            "--to", to,
            "--subject", subject,
            "--body", body,
        ]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd opencode-widget && swift test --filter QuotaLedgerServiceTests`
Expected: PASS.

- [ ] **Step 5: Hook into DataFetcher.refreshAll**

In `DataFetcher.swift`, capture the snapshots after the balances/quota resolve. Add a `ledger: QuotaLedgerService? = nil` parameter defaulting to `nil` so existing tests that don't pass it keep working (they exercise the pure logic). In the two `WidgetCache(...)` construction sites (missing-auth path and the main return path), after building `deepseekBalanceHistory`/`openAIQuotaHistory`, call an injected callback:

```swift
// signature
static func refreshAll(
    dbPath: ...,
    authPath: ...,
    session: URLSession = .shared,
    openAIAuthPath: ...,
    cacheSuiteName: ...,
    cacheFileName: ...,
    historyNow: Date = Date(),
    openCodeHistoryDBPath: String? = nil,
    hermesHistoryDBPath: ...,
    codexHistoryRoots: ...,
    historyFetcher: (@Sendable () -> UsageHistoryResult)? = nil,
    openAIQuotaFetcher: @escaping @Sendable ...,
    onQuotaRecord: (@Sendable (WidgetCache) -> Void)? = nil
) async -> WidgetCache {
```

Call `onQuotaRecord?(resultCache)` immediately before each `return`. Because `DataFetcher` is in the `OpencodeWidgetApp` target and `QuotaLedgerService` is also app target, wire it in `OpencodeWidgetApp.swift` refresh paths:

```swift
let cache = await DataFetcher.refreshAll(
    onQuotaRecord: { cached in
        QuotaLedgerService.shared.recordRefresh(cache: cached)
        Task { await QuotaLedgerService.shared.runMonthlyReportIfDue() }
    }
)
DataStore.save(cache: cache)
```

Do this in both `AppDelegate.refreshData()` and `MenuContent.refreshData()` (manual refresh).

- [ ] **Step 6: Also back-fill on first launch from AppDelegate**

In `AppDelegate.applicationDidFinishLaunching`, after `refreshData()` first runs, call `QuotaLedgerService.shared.begin(of: cache)` if needed. Simplest: in `refreshData`, after obtaining `cache`, call `QuotaLedgerService.shared.recordRefresh(cache: cache)` (which back-fills when count==0).

- [ ] **Step 7: Full verification and commit**

Run: `cd opencode-widget && swift test`
Expected: full suite passes (existing 144 + new ledger/reporter tests).

```bash
git add opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift opencode-widget/Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift opencode-widget/Sources/OpencodeWidgetApp/QuotaLedgerService.swift opencode-widget/Tests/OpencodeWidgetAppTests/QuotaLedgerServiceTests.swift
git commit -m "feat: record quota snapshots and run month-end report from app"
```

---

### Task 4: Validation build, deploy, and end-to-end email smoke test

**Files:**
- None new (verification only).

**Interfaces:**
- Consumes: the wired feature from Task 3.

- [ ] **Step 1: Build and run all tests**

```bash
cd opencode-widget && swift test
xcodegen generate
xcodebuild -scheme OpencodeWidgetApp -configuration Release build
```

Expected: all tests pass; Release build succeeds.

- [ ] **Step 2: Verify the app creates the ledger and archives on refresh**

Launch the app. Confirm the ledger DB exists:

```bash
ls -la ~/Library/Application\ Support/OpencodeWidgetApp/quota.db
sqlite3 ~/Library/Application\ Support/OpencodeWidgetApp/quota.db '.tables'
sqlite3 ~/Library/Application\ Support/OpencodeWidgetApp/quota.db 'SELECT COUNT(*) FROM quota_snapshots;'
```

- [ ] **Step 3: Manual email smoke test (user)**

Temporarily set `now` to a last-day-of-month date, or run the reporter directly, to confirm one email to `fathur6@gmail.com`. Confirm delivery and mark the month so it isn't re-sent. This is a manual step performed by the user; do NOT automate a real send from tests.

- [ ] **Step 4: Commit any docs and push**

```bash
git add -A
git commit -m "chore: verify quota ledger + month-end email wiring"
```

---

## Plan Self-Review

- **Spec coverage:** Ledger (Task 1), monthly reporter + CSV/summary + last-day gate + email + archive + idempotency + empty-month + failure retry (Task 2), capture/back-fill + app wiring (Task 3), validation + email smoke (Task 4).
- **Type consistency:** `QuotaSnapshotRow`, `QuotaLedger`, `QuotaEmailSending`, `QuotaMonthlyReporter`, `QuotaReportFormatter`, `QuotaLedgerService` are defined before use and names match across tasks.
- **Placeholders:** none — all steps carry full code and commands.
