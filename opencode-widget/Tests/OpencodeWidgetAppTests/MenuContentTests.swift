import XCTest
@testable import OpencodeWidgetApp
@testable import OpencodeWidgetShared

@MainActor
final class MenuContentTests: XCTestCase {
    func testQuotaTextShowsRemainingPercentage() {
        XCTAssertEqual(MenuContent.quotaText(OpenAIQuota(remainingPercent: 97)), "97% remaining")
    }

    func testQuotaTextShowsUnavailableWhenMissing() {
        XCTAssertEqual(MenuContent.quotaText(nil), "Quota unavailable")
    }

    func testResetTextShowsMonthAndDay() {
        let date = Date(timeIntervalSince1970: 1_784_764_800)
        XCTAssertTrue(MenuContent.resetText(date).hasPrefix("Resets Jul 23"))
    }

    func testResetTextIsEmptyWhenMissing() {
        XCTAssertEqual(MenuContent.resetText(nil), "")
    }
}
