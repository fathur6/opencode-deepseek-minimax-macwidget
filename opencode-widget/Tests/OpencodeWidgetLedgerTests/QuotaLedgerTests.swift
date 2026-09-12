import XCTest
import SQLite3
@testable import OpencodeWidgetLedger
import OpencodeWidgetShared

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

    func testRecordUpsertPreservesUnavailableProviderBalances() {
        let hour = Date(timeIntervalSince1970: 1_800_000_000)
        ledger.record(hour: hour, deepseekUSD: 10, openaiPercent: 44, source: "both")
        ledger.record(hour: hour, deepseekUSD: nil, openaiPercent: nil, source: "unknown")

        let rows = ledger.monthRows(month: hour)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].deepseekUSD, 10)
        XCTAssertEqual(rows[0].openaiPercent, 44)
        XCTAssertEqual(rows[0].source, "unknown")
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

    func testBackfillMergesBothSeriesPerHour() {
        let hour = Date(timeIntervalSince1970: 1_800_000_000)
        let ds = [
            DeepSeekBalanceSnapshot(hour: hour, remainingRM: 45)
        ]
        let oa = [
            OpenAIQuotaSnapshot(hour: hour, remainingPercent: 60)
        ]
        ledger.backfill(deepseek: ds, openAI: oa)
        let rows = ledger.monthRows(month: hour)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].source, "both")
        XCTAssertEqual(rows[0].deepseekUSD ?? 0, 45 / 4.5, accuracy: 0.0001)
        XCTAssertEqual(rows[0].openaiPercent ?? 0, 60)
    }

    func testRecentSnapshotsReturnsLimitMostRecentAscending() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        for i in 0..<5 {
            ledger.record(hour: base.addingTimeInterval(Double(i) * 3_600), deepseekUSD: 10, openaiPercent: 50, source: "both")
        }
        let recent = ledger.recentSnapshots(limit: 3)
        XCTAssertEqual(recent.count, 3)
        // most recent (descending query) must be sorted ascending by hour
        XCTAssertLessThan(recent[0].hour, recent[1].hour)
        XCTAssertLessThan(recent[1].hour, recent[2].hour)
        XCTAssertEqual(recent.last?.hour, base.addingTimeInterval(4 * 3_600))
    }

    func testRecordReplacesSameHoursUsageAndCost() {
        let hour = Date(timeIntervalSince1970: 1_800_000_000)
        ledger.record(hour: hour, deepseekUSD: 4, openaiPercent: 70, deepseekInputTokens: 10, openAIInputTokens: 100, openAIEstimatedCostUSD: 0.25, source: "all")
        ledger.record(hour: hour, deepseekUSD: 3, openaiPercent: 60, deepseekInputTokens: 20, openAIInputTokens: 200, openAIEstimatedCostUSD: 0.75, source: "all")

        XCTAssertEqual(ledger.count(), 1)
        XCTAssertEqual(ledger.recentSnapshots(limit: 1).first?.openAIInputTokens, 200)
        XCTAssertEqual(ledger.recentSnapshots(limit: 1).first?.openAIEstimatedCostUSD, 0.75)
    }

    func testActiveOpenAICostIncludesOnlyQuotaWindow() {
        let reset = Date(timeIntervalSince1970: 2_000_001_600)
        ledger.record(hour: reset.addingTimeInterval(-169 * 3_600), deepseekUSD: nil, openaiPercent: nil, deepseekInputTokens: nil, openAIInputTokens: 1, openAIEstimatedCostUSD: 9, source: "openai")
        ledger.record(hour: reset.addingTimeInterval(-168 * 3_600), deepseekUSD: nil, openaiPercent: nil, deepseekInputTokens: nil, openAIInputTokens: 1, openAIEstimatedCostUSD: 2, source: "openai")
        ledger.record(hour: reset.addingTimeInterval(-1 * 3_600), deepseekUSD: nil, openaiPercent: nil, deepseekInputTokens: nil, openAIInputTokens: 1, openAIEstimatedCostUSD: 3, source: "openai")

        XCTAssertEqual(ledger.activeOpenAIEstimatedCost(from: reset.addingTimeInterval(-168 * 3_600), through: reset), 5)
    }

    func testActiveOpenAICostUsesSuppliedInclusiveBounds() {
        let hour = Date(timeIntervalSince1970: 1_800_000_000)
        ledger.record(hour: hour, deepseekUSD: nil, openaiPercent: nil, openAIEstimatedCostUSD: 1, source: "openai")
        ledger.record(hour: hour.addingTimeInterval(3_600), deepseekUSD: nil, openaiPercent: nil, openAIEstimatedCostUSD: 2, source: "openai")

        XCTAssertEqual(
            ledger.activeOpenAIEstimatedCost(
                from: hour.addingTimeInterval(1_800),
                through: hour.addingTimeInterval(5_400)
            ),
            2
        )
    }

    func testMigrationPreservesOriginalAndCurrentSchemaRawValuesOnEveryReopen() throws {
        for current in [false, true] {
            let path = dbPath + (current ? "-current" : "-original")
            defer { try? FileManager.default.removeItem(atPath: path) }
            var db: OpaquePointer?
            XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
            defer { sqlite3_close(db) }
            let extras = current ? ", deepseek_input_tokens INTEGER, openai_input_tokens INTEGER, openai_estimated_cost_usd REAL" : ""
            XCTAssertEqual(sqlite3_exec(db, """
                CREATE TABLE quota_snapshots(hour TEXT PRIMARY KEY, deepseek_usd REAL, openai_percent REAL, source TEXT, recorded_at TEXT\(extras));
                CREATE TABLE quota_month_mark(yyyy_mm TEXT PRIMARY KEY, emailed_at TEXT);
                INSERT INTO quota_month_mark VALUES ('2020-01','unchanged'), ('2020-02',NULL);
                INSERT INTO quota_snapshots(hour,deepseek_usd,openai_percent,source,recorded_at) VALUES
                  ('2020-01-01T00:00:00Z',NULL,0,NULL,'original timestamp'),
                  ('2020-01-01T01:00:00Z',0,NULL,'fixture',NULL),
                  ('2020-01-01T02:00:00Z',12.5,45.5,'both','preserve me');
                """, nil, nil, nil), SQLITE_OK)
            if current {
                XCTAssertEqual(sqlite3_exec(db, "UPDATE quota_snapshots SET deepseek_input_tokens=123, openai_input_tokens=456, openai_estimated_cost_usd=7.89 WHERE source='both'; UPDATE quota_snapshots SET deepseek_input_tokens=0,openai_input_tokens=0,openai_estimated_cost_usd=0 WHERE source='fixture';", nil, nil, nil), SQLITE_OK)
            }
            let columns = "hour,deepseek_usd,openai_percent,source,recorded_at" + (current ? ",deepseek_input_tokens,openai_input_tokens,openai_estimated_cost_usd" : "")
            let projection = "SELECT \(columns) FROM quota_snapshots ORDER BY hour"
            let before = try rawRows(db, projection)
            let marks = try rawRows(db, "SELECT * FROM quota_month_mark ORDER BY yyyy_mm")
            for _ in 0..<3 {
                var migrated: QuotaLedger? = QuotaLedger(path: path)
                XCTAssertNil(migrated?.migrationError)
                XCTAssertEqual(migrated?.count(), 3)
                XCTAssertEqual(try rawRows(db, projection), before)
                XCTAssertEqual(try rawRows(db, "SELECT * FROM quota_month_mark ORDER BY yyyy_mm"), marks)
                XCTAssertEqual(try rawRows(db, "SELECT openai_five_hour_percent,openai_five_hour_reset_at FROM quota_snapshots"), Array(repeating: [nil, nil], count: 3))
                XCTAssertTrue(migrated?.recentSnapshots(limit: 3).allSatisfy { $0.fiveHourRemainingPercent == nil && $0.fiveHourResetDate == nil } ?? false)
                XCTAssertEqual(try rawRows(db, "PRAGMA integrity_check"), [["3:ok"]])
                migrated = nil
            }
        }
    }

    func testFiveHourValuesSurviveUpsertBothReadersAndReopen() throws {
        let hour = Date(timeIntervalSince1970: 1_800_000_000)
        let reset = hour.addingTimeInterval(18000.5)
        ledger.record(hour: hour, deepseekUSD: 12, openaiPercent: 45, deepseekInputTokens: 123, openAIInputTokens: 456, openAIEstimatedCostUSD: 7.89, fiveHourRemainingPercent: 80, fiveHourResetDate: reset, source: "both")
        ledger.record(hour: hour, deepseekUSD: nil, openaiPercent: nil, fiveHourRemainingPercent: 60, source: "openai")
        ledger.record(hour: hour, deepseekUSD: nil, openaiPercent: nil, source: "unavailable")
        for _ in 0..<3 {
            let rows = ledger.rows(from: hour, to: hour.addingTimeInterval(3600))
            XCTAssertEqual(rows, ledger.recentSnapshots(limit: 1))
            let row = try XCTUnwrap(rows.first)
            XCTAssertEqual(row.fiveHourRemainingPercent, 60)
            XCTAssertEqual(row.fiveHourResetDate, reset)
            XCTAssertEqual(row.deepseekUSD, 12)
            XCTAssertEqual(row.openaiPercent, 45)
            XCTAssertEqual(row.deepseekInputTokens, 123)
            XCTAssertEqual(row.openAIInputTokens, 456)
            XCTAssertEqual(row.openAIEstimatedCostUSD, 7.89)
            ledger = nil
            ledger = QuotaLedger(path: dbPath)
        }
    }

    func testLockedMigrationReportsSanitizedFailureWithoutChangingRows() throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbPath, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "BEGIN EXCLUSIVE", nil, nil, nil), SQLITE_OK)
        let unavailable = QuotaLedger(path: dbPath)
        XCTAssertEqual(unavailable.migrationError, "Quota ledger schema migration failed.")
        XCTAssertEqual(sqlite3_exec(db, "ROLLBACK", nil, nil, nil), SQLITE_OK)
        XCTAssertNil(QuotaLedger(path: dbPath).migrationError)
    }

    private func rawRows(_ db: OpaquePointer?, _ sql: String) throws -> [[String?]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            XCTFail("Fixture query failed")
            throw NSError(domain: "FixtureSQL", code: 1)
        }
        defer { sqlite3_finalize(statement) }
        var result: [[String?]] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            result.append((0..<sqlite3_column_count(statement)).map { index in
                let type = sqlite3_column_type(statement, index)
                guard type != SQLITE_NULL, let text = sqlite3_column_text(statement, index) else { return nil }
                return "\(type):" + String(cString: text)
            })
            status = sqlite3_step(statement)
        }
        XCTAssertEqual(status, SQLITE_DONE)
        return result
    }

    func testFailedAdditionRollsBackEarlierAdditionAndIndexCreation() throws {
        let path = dbPath + "-rollback"
        defer { try? FileManager.default.removeItem(atPath: path) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        // Leave exactly one column slot: the first addition succeeds and the
        // second must fail. This exercises rollback after a partial migration.
        let limit = Int(sqlite3_limit(db, SQLITE_LIMIT_COLUMN, -1))
        let padding = (0..<(limit - 6)).map { "fixture_\($0) INTEGER" }.joined(separator: ",")
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE quota_snapshots(hour TEXT PRIMARY KEY,deepseek_usd REAL,openai_percent REAL,source TEXT,recorded_at TEXT,\(padding)); INSERT INTO quota_snapshots(hour,openai_percent) VALUES('old',0);", nil, nil, nil), SQLITE_OK)
        let schemaBefore = try rawRows(db, "SELECT type,name,sql FROM sqlite_schema ORDER BY name")
        let valuesBefore = try rawRows(db, "SELECT * FROM quota_snapshots")
        let failed = QuotaLedger(path: path)
        XCTAssertEqual(failed.migrationError, "Quota ledger schema migration failed.")
        XCTAssertEqual(try rawRows(db, "SELECT type,name,sql FROM sqlite_schema ORDER BY name"), schemaBefore)
        XCTAssertEqual(try rawRows(db, "SELECT * FROM quota_snapshots"), valuesBefore)
    }
}
