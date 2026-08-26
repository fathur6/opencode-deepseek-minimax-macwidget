import XCTest
@testable import OpencodeWidgetApp
@testable import OpencodeWidgetShared

final class RemainingQuotaChartTests: XCTestCase {
    func testChartAcceptsHourlyUsageForBackgroundConsumption() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let chart = RemainingQuotaChart(
            deepseekSnapshots: [],
            openAISnapshots: [],
            hourlyUsage: [HourlyUsageBucket(hour: start, openAIInputTokens: 120)],
            xDomain: start...start.addingTimeInterval(167 * 3_600)
        )

        XCTAssertNotNil(chart)
    }

    func testProjectionAssignsColorsAndPlotDomain() {
        let start = Date(timeIntervalSince1970: 0)
        let deepseek = [DeepSeekBalanceSnapshot(hour: start, remainingRM: 30)]
        let openAI = [OpenAIQuotaSnapshot(hour: start, remainingPercent: 44)]
        let xDomain = start...start.addingTimeInterval(167 * 3_600)

        let projection = RemainingQuotaChartProjection(
            deepseekSnapshots: deepseek,
            openAISnapshots: openAI,
            xDomain: xDomain
        )

        XCTAssertEqual(projection.deepseekSeriesColor, "blue")
        XCTAssertEqual(projection.openAISeriesColor, "green")
        XCTAssertEqual(projection.xDomain, xDomain)
        XCTAssertEqual(projection.plotYDomain, 0...1)
        XCTAssertTrue(projection.usdAxisMax > 0)
        XCTAssertEqual(projection.percentAxisMax, 100)
    }

    func testProjectionNormalizesBothSeriesOntoOnePlotDomain() {
        let start = Date(timeIntervalSince1970: 0)
        let deepseek = [DeepSeekBalanceSnapshot(hour: start, remainingRM: 20)]
        let openAI = [OpenAIQuotaSnapshot(hour: start, remainingPercent: 100)]
        let xDomain = start...start.addingTimeInterval(167 * 3_600)

        let projection = RemainingQuotaChartProjection(
            deepseekSnapshots: deepseek,
            openAISnapshots: openAI,
            xDomain: xDomain
        )

        let allY = projection.deepseekPoints.map(\.y) + projection.openAIPoints.map(\.y)
        XCTAssertFalse(allY.isEmpty)
        XCTAssertTrue(allY.allSatisfy { (0...1).contains($0) })
        XCTAssertLessThanOrEqual(projection.deepseekPoints.first?.y ?? 2, 1)
        XCTAssertLessThanOrEqual(projection.openAIPoints.first?.y ?? 2, 1)
    }

    func testProjectionKeepsEachSeriesDistinct() {
        let start = Date(timeIntervalSince1970: 0)
        let deepseek = [DeepSeekBalanceSnapshot(hour: start, remainingRM: 20)]
        let openAI = [OpenAIQuotaSnapshot(hour: start, remainingPercent: 100)]
        let xDomain = start...start.addingTimeInterval(167 * 3_600)

        let projection = RemainingQuotaChartProjection(
            deepseekSnapshots: deepseek,
            openAISnapshots: openAI,
            xDomain: xDomain
        )

        XCTAssertFalse(projection.deepseekPoints.isEmpty)
        XCTAssertFalse(projection.openAIPoints.isEmpty)
        XCTAssertNotEqual(projection.deepseekSeriesColor, projection.openAISeriesColor)
    }

    func testProjectionCombinesProviderInputTokensAndCapsMaximumBarAtOneThird() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let buckets = [
            HourlyUsageBucket(hour: start, openAIInputTokens: 100, deepseekInputTokens: 200),
            HourlyUsageBucket(hour: start.addingTimeInterval(3_600), openAIInputTokens: 300, deepseekInputTokens: 300)
        ]

        let projection = RemainingQuotaChartProjection(
            deepseekSnapshots: [],
            openAISnapshots: [],
            hourlyUsage: buckets,
            xDomain: start...start.addingTimeInterval(167 * 3_600)
        )

        XCTAssertEqual(projection.consumption.map(\.tokens), [300, 600])
        XCTAssertEqual(projection.consumption[0].y, 1.0 / 6.0, accuracy: 0.000_001)
        XCTAssertEqual(projection.consumption[1].y, 1.0 / 3.0, accuracy: 0.000_001)
    }

    func testProjectionUsesZeroHeightConsumptionBarsWhenWindowHasNoTokens() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let buckets = [
            HourlyUsageBucket(hour: start),
            HourlyUsageBucket(hour: start.addingTimeInterval(3_600))
        ]

        let projection = RemainingQuotaChartProjection(
            deepseekSnapshots: [],
            openAISnapshots: [],
            hourlyUsage: buckets,
            xDomain: start...start.addingTimeInterval(167 * 3_600)
        )

        XCTAssertEqual(projection.consumption.map(\.y), [0, 0])
    }
}
