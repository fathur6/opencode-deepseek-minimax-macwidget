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

    func testMenuBarStateUpdateKeepsDeepSeekBalanceHistory() {
        let state = MenuBarState()
        let history = [DeepSeekBalanceSnapshot(hour: Date(timeIntervalSince1970: 3_600), remainingRM: 45)]

        state.update(with: WidgetCache(deepseekBalanceHistory: history))

        XCTAssertEqual(state.deepseekBalanceHistory, history)
    }
}
