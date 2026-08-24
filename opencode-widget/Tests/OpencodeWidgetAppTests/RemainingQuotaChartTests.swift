import XCTest
@testable import OpencodeWidgetApp
@testable import OpencodeWidgetShared

final class RemainingQuotaChartTests: XCTestCase {
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
        XCTAssertTrue(projection.rmAxisMax > 0)
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
}
