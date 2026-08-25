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

    func testEstimatedCostTextUsesEstimateLabel() {
        XCTAssertEqual(MenuContent.estimatedCostText(12.345), "Est. $12.35")
        XCTAssertEqual(MenuContent.estimatedCostText(0), "Est. $0.00")
    }

    func testMenuBarStateRetainsEstimateWhenResetDateMissing() {
        let state = MenuBarState(estimatedCost: { _ in 42.0 })
        state.update(with: WidgetCache(openAIQuota: OpenAIQuota(remainingPercent: 50, resetDate: Date(timeIntervalSince1970: 2_000_000_000))))
        XCTAssertEqual(state.openAIEstimatedCost, 42.0)

        state.update(with: WidgetCache(openAIQuota: OpenAIQuota(remainingPercent: 50, resetDate: nil)))
        XCTAssertEqual(state.openAIEstimatedCost, 42.0)
    }

    func testMenuBarStateShowsZeroEstimateWhenNeverComputed() {
        let state = MenuBarState()
        state.update(with: WidgetCache(openAIQuota: OpenAIQuota(remainingPercent: 50, resetDate: nil)))
        XCTAssertEqual(state.openAIEstimatedCost, 0.0)
        XCTAssertEqual(MenuContent.estimatedCostText(state.openAIEstimatedCost), "Est. $0.00")
    }

    func testMenuBarStateUpdateKeepsDeepSeekBalanceHistory() {
        let state = MenuBarState()
        let history = [DeepSeekBalanceSnapshot(hour: Date(timeIntervalSince1970: 3_600), remainingRM: 45)]

        state.update(with: WidgetCache(deepseekBalanceHistory: history))

        XCTAssertEqual(state.deepseekBalanceHistory, history)
    }

    func testPreviousOffsetMovesBackOneDayWithoutExceedingHistory() {
        XCTAssertEqual(MenuContent.previousOffset(current: 0, historyCount: 720), 24)
        XCTAssertEqual(MenuContent.previousOffset(current: 552, historyCount: 720), 552)
    }

    func testNextOffsetMovesTowardLiveWindow() {
        XCTAssertEqual(MenuContent.nextOffset(current: 24), 0)
        XCTAssertEqual(MenuContent.nextOffset(current: 0), 0)
    }
}
