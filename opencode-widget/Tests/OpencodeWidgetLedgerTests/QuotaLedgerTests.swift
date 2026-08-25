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
}
