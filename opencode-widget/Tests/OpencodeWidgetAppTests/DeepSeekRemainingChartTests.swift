import XCTest
@testable import OpencodeWidgetApp
@testable import OpencodeWidgetShared

final class DeepSeekRemainingChartTests: XCTestCase {
    func testChartWindowMovesOneDayButKeepsOneHundredSixtyEightHours() {
        let newestHour = Date(timeIntervalSince1970: Double(719 * 3_600))
        let range = ChartWindow.range(endingAt: newestHour, offsetHours: 24)

        XCTAssertEqual(range.lowerBound, Date(timeIntervalSince1970: Double(528 * 3_600)))
        XCTAssertEqual(range.upperBound, Date(timeIntervalSince1970: Double(695 * 3_600)))
    }

    func testProjectionUsesCombinedHourlyInputTokensInsteadOfBalanceDeltas() {
        let start = Date(timeIntervalSince1970: 0)
        let hourlyUsage = [
            HourlyUsageBucket(hour: start, openAIInputTokens: -100, deepseekInputTokens: 400),
            HourlyUsageBucket(hour: start.addingTimeInterval(3_600), openAIInputTokens: 200, deepseekInputTokens: 600)
        ]

        let projection = RemainingQuotaChartProjection(
            deepseekSnapshots: [],
            openAISnapshots: [],
            hourlyUsage: hourlyUsage,
            xDomain: start...start.addingTimeInterval(167 * 3_600)
        )

        XCTAssertEqual(projection.consumption.map(\.tokens), [400, 800])
        XCTAssertEqual(projection.consumption.map(\.y), [1.0 / 6.0, 1.0 / 3.0])
    }

    func testProjectionRetainsTheProvidedDomainWhenHistoryIsEmpty() {
        let start = Date(timeIntervalSince1970: 0)
        let range = start...start.addingTimeInterval(167 * 3_600)

        XCTAssertEqual(
            RemainingQuotaChartProjection(deepseekSnapshots: [], openAISnapshots: [], xDomain: range).xDomain,
            range
        )
    }

    func testProjectionExposesInitialSnapshotAsBalanceMarker() {
        let snapshot = DeepSeekBalanceSnapshot(
            hour: Date(timeIntervalSince1970: 3_600),
            remainingRM: 32.355
        )
        let projection = RemainingQuotaChartProjection(
            deepseekSnapshots: [snapshot],
            openAISnapshots: [],
            xDomain: Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 167 * 3_600)
        )

        XCTAssertEqual(projection.deepseekPoints.first?.hour, snapshot.hour)
        XCTAssertEqual(projection.deepseekPoints.first?.series, "DeepSeek")
    }
}
