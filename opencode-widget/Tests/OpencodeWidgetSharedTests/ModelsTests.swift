import XCTest
@testable import OpencodeWidgetShared

final class ModelsTests: XCTestCase {

    func testHourlyUsageBucketAndCacheRoundTrip() throws {
        let bucket = HourlyUsageBucket(
            hour: Date(timeIntervalSince1970: 3_600),
            openAIInputTokens: 12,
            deepseekInputTokens: 9,
            smoothedOpenAIInputTokens: 6.5,
            smoothedDeepseekInputTokens: 4.5
        )
        let original = WidgetCache(hourlyUsage: [bucket])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetCache.self, from: data)

        XCTAssertEqual(decoded.hourlyUsage, [bucket])
        XCTAssertFalse(decoded.isEmpty)
    }

    func testWidgetCacheDecodesLegacyPayloadWithoutHourlyUsage() throws {
        let json = #"""
        {
          "lastUpdated": 0,
          "deepseek": {"currency": "USD"},
          "minimax": {"currency": "USD"},
          "dailyUsage": []
        }
        """#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let decoded = try decoder.decode(WidgetCache.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.hourlyUsage, [])
    }

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

    func testOpenAIQuotaRoundTrip() throws {
        let quota = OpenAIQuota(
            remainingPercent: 97,
            resetDate: Date(timeIntervalSince1970: 1_752_556_800)
        )
        let data = try JSONEncoder().encode(quota)
        XCTAssertEqual(try JSONDecoder().decode(OpenAIQuota.self, from: data), quota)
    }

    func testWidgetCacheRoundTripIncludesOpenAIQuota() throws {
        let quota = OpenAIQuota(remainingPercent: 97, resetDate: Date(timeIntervalSince1970: 0))
        let original = WidgetCache(openAIQuota: quota)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(WidgetCache.self, from: data).openAIQuota, quota)
    }

    func testWidgetCacheWithOnlyOpenAIQuotaIsNotEmpty() {
        XCTAssertFalse(WidgetCache(openAIQuota: OpenAIQuota(remainingPercent: 97)).isEmpty)
    }

    // MARK: - QuotaResetTimeline (168h cycle math)

    func testTimelineAtResetEndOfCycle() {
        let reset = Date(timeIntervalSince1970: 1_000_000)
        let now = reset
        let timeline = QuotaResetTimeline(resetDate: reset)
        // At the reset instant nothing remains → elapsed = 168h → fraction 1.0 (right edge)
        XCTAssertEqual(timeline.remainingHours(at: now), 0, accuracy: 0.001)
        XCTAssertEqual(timeline.elapsedFraction(at: now), 1.0, accuracy: 0.001)
    }

    func testTimelineJustAfterResetStartsAtLeftEdge() {
        let reset = Date(timeIntervalSince1970: 1_000_000)
        let now = reset.addingTimeInterval(-168 * 3600)
        let timeline = QuotaResetTimeline(resetDate: reset)
        // 168h remaining → elapsed = 0 → fraction 0 (left edge)
        XCTAssertEqual(timeline.remainingHours(at: now), 168, accuracy: 0.001)
        XCTAssertEqual(timeline.elapsedFraction(at: now), 0, accuracy: 0.001)
    }

    func testTimelineHalfwayElapsed() {
        let reset = Date(timeIntervalSince1970: 1_000_000)
        let now = reset.addingTimeInterval(-84 * 3600)
        let timeline = QuotaResetTimeline(resetDate: reset)
        XCTAssertEqual(timeline.elapsedFraction(at: now), 0.5, accuracy: 0.001)
    }

    func testTimelineClampedToFullAfterReset() {
        let reset = Date(timeIntervalSince1970: 1_000_000)
        let past = reset.addingTimeInterval(3600)
        let timeline = QuotaResetTimeline(resetDate: reset)
        XCTAssertEqual(timeline.remainingHours(at: past), 0, accuracy: 0.001)
        XCTAssertEqual(timeline.elapsedFraction(at: past), 1.0, accuracy: 0.001)
    }

    func testTimelineRoundedRemainingHoursFormula() {
        let reset = Date(timeIntervalSince1970: 1_000_000)
        let now = reset.addingTimeInterval(-167.4 * 3600)
        let timeline = QuotaResetTimeline(resetDate: reset)
        // 167.4 remaining rounds to 167 → elapsed = 168 − 167 = 1h
        XCTAssertEqual(timeline.elapsedHours(at: now), 1, accuracy: 0.001)
    }

    func testTimelineNegativeRemainingClampsToZero() {
        let reset = Date(timeIntervalSince1970: 1_000_000)
        let now = reset.addingTimeInterval(7200)
        let timeline = QuotaResetTimeline(resetDate: reset)
        XCTAssertEqual(timeline.remainingHours(at: now), 0, accuracy: 0.001)
    }

    func testTimelineApproachingResetMarkerNearRightEdge() {
        let reset = Date(timeIntervalSince1970: 1_000_000)
        let now = reset.addingTimeInterval(-0.4 * 3600)
        let timeline = QuotaResetTimeline(resetDate: reset)
        // 0.4h remaining rounds to 0 → elapsed = 168h → fraction 1.0
        XCTAssertEqual(timeline.elapsedFraction(at: now), 1.0, accuracy: 0.001)
    }

    func testTimelineEarlyCycleMarkerNearLeftEdge() {
        let reset = Date(timeIntervalSince1970: 1_000_000)
        let now = reset.addingTimeInterval(-167.6 * 3600)
        let timeline = QuotaResetTimeline(resetDate: reset)
        // 167.6h remaining rounds to 168 → elapsed = 0h → fraction 0
        XCTAssertEqual(timeline.elapsedFraction(at: now), 0, accuracy: 0.001)
    }

    // MARK: - MiniMaxUsage

    func testMiniMaxUsagePercentage() {
        let usage = MiniMaxUsage(remainingPrompts: 75, totalPrompts: 100)
        XCTAssertEqual(usage.percentage, 0.75)
    }

    func testMiniMaxUsageZeroTotal() {
        let usage = MiniMaxUsage(remainingPrompts: 0, totalPrompts: 0)
        XCTAssertEqual(usage.percentage, 0)
    }

    func testMiniMaxUsageDefaultValues() {
        let usage = MiniMaxUsage()
        XCTAssertEqual(usage.remainingPrompts, 0)
        XCTAssertEqual(usage.totalPrompts, 0)
    }

    func testMiniMaxUsageEquality() {
        let a = MiniMaxUsage(remainingPrompts: 50, totalPrompts: 100)
        let b = MiniMaxUsage(remainingPrompts: 50, totalPrompts: 100)
        XCTAssertEqual(a, b)
    }

    func testMiniMaxUsageCodableRoundTrip() throws {
        let original = MiniMaxUsage(remainingPrompts: 145, totalPrompts: 200)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MiniMaxUsage.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testWidgetCacheRoundTripIncludesMiniMaxUsage() throws {
        let original = WidgetCache(
            lastUpdated: Date(timeIntervalSince1970: 0),
            deepseek: ProviderBalance(balance: 100.0),
            minimax: ProviderBalance(balance: nil),
            minimaxUsage: MiniMaxUsage(remainingPrompts: 145, totalPrompts: 200),
            dailyUsage: [DailyUsageRow(date: "2026-06-30")]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetCache.self, from: data)
        XCTAssertEqual(decoded.minimaxUsage, original.minimaxUsage)
        XCTAssertEqual(decoded.deepseek, original.deepseek)
        XCTAssertEqual(decoded.dailyUsage, original.dailyUsage)
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

    // MARK: - MiniMaxModelRemain

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

    // MARK: - ModelUsageRow

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
}
