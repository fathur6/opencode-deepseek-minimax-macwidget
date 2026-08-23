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

    func testProjectionClassifiesTopUpsAndConsumption() {
        let start = Date(timeIntervalSince1970: 0)
        let snapshots = [
            DeepSeekBalanceSnapshot(hour: start, remainingRM: 45),
            DeepSeekBalanceSnapshot(hour: start.addingTimeInterval(3_600), remainingRM: 40),
            DeepSeekBalanceSnapshot(hour: start.addingTimeInterval(7_200), remainingRM: 70)
        ]

        let projection = RemainingQuotaChartProjection(
            deepseekSnapshots: snapshots,
            openAISnapshots: [],
            xDomain: start...start.addingTimeInterval(167 * 3_600)
        )

        XCTAssertEqual(projection.consumption.map(\.amount), [5])
        XCTAssertEqual(projection.topUps.map(\.amount), [30])
        XCTAssertEqual(projection.topUps.first?.colorName, "green")
        XCTAssertEqual(projection.consumption.first?.colorName, "gray")
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
