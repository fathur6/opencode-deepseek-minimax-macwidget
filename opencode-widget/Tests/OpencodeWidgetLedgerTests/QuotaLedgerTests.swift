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
}
