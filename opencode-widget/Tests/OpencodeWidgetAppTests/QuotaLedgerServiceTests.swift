import XCTest
@testable import OpencodeWidgetApp
@testable import OpencodeWidgetLedger
import OpencodeWidgetShared

@MainActor
final class QuotaLedgerServiceTests: XCTestCase {
    func testOpenCreatesLedger() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("qs-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("quota.db").path
        let service = QuotaLedgerService(ledgerPath: path)
        XCTAssertNotNil(service.ledger)
        XCTAssertEqual(service.ledger.count(), 0)
    }

    func testRecordRefreshBackfillsOnceThenRecords() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("qs2-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("quota.db").path
        let service = QuotaLedgerService(ledgerPath: path)

        let hour = Date(timeIntervalSince1970: 1_800_000_000)
        let cache = WidgetCache(
            deepseek: ProviderBalance(balance: 10, currency: "USD"),
            openAIQuota: OpenAIQuota(remainingPercent: 44),
            deepseekBalanceHistory: [DeepSeekBalanceSnapshot(hour: hour, remainingRM: 45)],
            openAIQuotaHistory: [OpenAIQuotaSnapshot(hour: hour, remainingPercent: 60)]
        )
        service.recordRefresh(cache: cache)
        XCTAssertGreaterThanOrEqual(service.ledger.count(), 2)

        service.recordRefresh(cache: cache)
        XCTAssertGreaterThanOrEqual(service.ledger.count(), 1)
    }

    func testRecordRefreshPreservesCurrentHourOpenAIUsageWhenCollectionIsUnavailable() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("qs3-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("quota.db").path
        let now = Date(timeIntervalSince1970: 1_800_000_123)
        let service = QuotaLedgerService(ledgerPath: path, now: { now }, hourlyTotals: { nil })
        service.ledger.record(
            hour: now,
            deepseekUSD: nil,
            openaiPercent: nil,
            openAIInputTokens: 123,
            openAIEstimatedCostUSD: 4.56,
            source: "openai"
        )

        service.recordRefresh(cache: WidgetCache(deepseek: ProviderBalance(balance: 10, currency: "USD")))

        let row = service.ledger.recentSnapshots(limit: 1).first
        XCTAssertEqual(row?.openAIInputTokens, 123)
        XCTAssertEqual(row?.openAIEstimatedCostUSD, 4.56)
    }

    func testCostWindowStartsOneHundredSixtyEightHoursBeforeReset() {
        let reset = Date(timeIntervalSince1970: 2_000_000_000)
        XCTAssertEqual(
            QuotaLedgerService.costWindowStart(resetDate: reset),
            reset.addingTimeInterval(-168 * 3_600)
        )
    }
}
