import XCTest
@testable import OpencodeWidgetApp
@testable import OpencodeWidgetShared

final class RemainingQuotaChartTests: XCTestCase {
    func testProjectionAssignsColorsAndAxes() {
        let start = Date(timeIntervalSince1970: 0)
        let deepseek = [DeepSeekBalanceSnapshot(hour: start, remainingRM: 30)]
        let openAI = [OpenAIQuotaSnapshot(hour: start, remainingPercent: 44)]
        let xDomain = start...start.addingTimeInterval(167 * 3_600)

        let projection = RemainingQuotaChartProjection(
            deepseekSnapshots: deepseek,
            openAISnapshots: openAI,
            xDomain: xDomain
        )

        XCTAssertEqual(projection.deepseek.colorName, "blue")
        XCTAssertEqual(projection.openAI.colorName, "green")
        XCTAssertEqual(projection.xDomain, xDomain)
        XCTAssertTrue(projection.deepseekRMYDomain.upperBound > 0)
        XCTAssertEqual(projection.openAIPercentYDomain.upperBound, 110)
    }
}
