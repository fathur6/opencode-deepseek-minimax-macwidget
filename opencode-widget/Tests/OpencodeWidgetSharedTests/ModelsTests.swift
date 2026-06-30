import XCTest
@testable import OpencodeWidgetShared

final class ModelsTests: XCTestCase {

    // MARK: - ProviderBalance encoding/decoding round-trip

    func testProviderBalanceEncodingDecodingRoundTrip() throws {
        let original = ProviderBalance(balance: 100.50, currency: "USD")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProviderBalance.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testProviderBalanceDefaultValues() throws {
        let balance = ProviderBalance()
        XCTAssertNil(balance.balance)
        XCTAssertEqual(balance.currency, "USD")
    }

    func testProviderBalanceCustomCurrency() throws {
        let balance = ProviderBalance(balance: 50.0, currency: "EUR")
        let data = try JSONEncoder().encode(balance)
        let decoded = try JSONDecoder().decode(ProviderBalance.self, from: data)
        XCTAssertEqual(decoded.balance, 50.0)
        XCTAssertEqual(decoded.currency, "EUR")
    }

    // MARK: - DailyUsageRow computed properties

    func testDailyUsageRowTotalTokens() {
        let row = DailyUsageRow(date: "2026-06-30", deepseekTokens: 100, minimaxTokens: 200)
        XCTAssertEqual(row.totalTokens, 300)
    }

    func testDailyUsageRowTotalCost() {
        let row = DailyUsageRow(date: "2026-06-30", deepseekCost: 1.5, minimaxCost: 2.5)
        XCTAssertEqual(row.totalCost, 4.0)
    }

    func testDailyUsageRowZeroValues() {
        let row = DailyUsageRow(date: "2026-06-29")
        XCTAssertEqual(row.totalTokens, 0)
        XCTAssertEqual(row.totalCost, 0)
    }

    // MARK: - DailyUsageRow Identifiable conformance

    func testDailyUsageRowIdentifiableIdEqualsDate() {
        let row = DailyUsageRow(date: "2026-06-30")
        XCTAssertEqual(row.id, "2026-06-30")
        XCTAssertEqual(row.id, row.date)
    }

    func testDailyUsageRowIdentifiableUniquePerDate() {
        let row1 = DailyUsageRow(date: "2026-06-30")
        let row2 = DailyUsageRow(date: "2026-07-01")
        XCTAssertNotEqual(row1.id, row2.id)
    }

    // MARK: - WidgetCache.isEmpty behavior

    func testWidgetCacheEmptyInitial() {
        let cache = WidgetCache()
        XCTAssertTrue(cache.isEmpty)
    }

    func testWidgetCacheNotEmptyWithDeepseekBalance() {
        let cache = WidgetCache(
            deepseek: ProviderBalance(balance: 50.0)
        )
        XCTAssertFalse(cache.isEmpty)
    }

    func testWidgetCacheNotEmptyWithMinimaxBalance() {
        let cache = WidgetCache(
            minimax: ProviderBalance(balance: 25.0)
        )
        XCTAssertFalse(cache.isEmpty)
    }

    func testWidgetCacheNotEmptyWithDailyUsage() {
        let cache = WidgetCache(
            dailyUsage: [DailyUsageRow(date: "2026-06-30")]
        )
        XCTAssertFalse(cache.isEmpty)
    }

    func testWidgetCacheEmptyWithExplicitZeroBalances() {
        let cache = WidgetCache(
            deepseek: ProviderBalance(balance: 0),
            minimax: ProviderBalance(balance: 0)
        )
        XCTAssertFalse(cache.isEmpty)
    }

    func testWidgetCacheCodableRoundTrip() throws {
        let original = WidgetCache(
            lastUpdated: Date(timeIntervalSince1970: 0),
            deepseek: ProviderBalance(balance: 100.0),
            minimax: ProviderBalance(balance: 50.0),
            dailyUsage: [
                DailyUsageRow(date: "2026-06-30", deepseekTokens: 10, minimaxTokens: 20)
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetCache.self, from: data)
        XCTAssertEqual(decoded.deepseek, original.deepseek)
        XCTAssertEqual(decoded.minimax, original.minimax)
        XCTAssertEqual(decoded.dailyUsage, original.dailyUsage)
    }
}
