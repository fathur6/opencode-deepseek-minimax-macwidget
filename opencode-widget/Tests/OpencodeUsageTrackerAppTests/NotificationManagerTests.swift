import XCTest
@testable import OpencodeUsageTrackerApp
@testable import OpencodeWidgetShared

final class NotificationManagerTests: XCTestCase {
    func testWarningAt85Percent() {
        let remain = MiniMaxModelRemain(modelName: "test", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 15, startTime: 0, endTime: 0, remainsTime: 0)
        let alerts = NotificationManager.checkThresholds(models: [remain])
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts[0].level, .warning)
    }

    func testCriticalAt95Percent() {
        let remain = MiniMaxModelRemain(modelName: "test", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 5, startTime: 0, endTime: 0, remainsTime: 0)
        let alerts = NotificationManager.checkThresholds(models: [remain])
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts[0].level, .critical)
    }

    func testNoAlertBelow85Percent() {
        let remain = MiniMaxModelRemain(modelName: "test", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 20, startTime: 0, endTime: 0, remainsTime: 0)
        let alerts = NotificationManager.checkThresholds(models: [remain])
        XCTAssertTrue(alerts.isEmpty)
    }

    func testCriticalTakesPriorityOverWarning() {
        let remain = MiniMaxModelRemain(modelName: "test", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 5, startTime: 0, endTime: 0, remainsTime: 0)
        let alerts = NotificationManager.checkThresholds(models: [remain])
        XCTAssertEqual(alerts[0].level, .critical)
    }

    func testMultipleModelsGenerateSeparateAlerts() {
        let models = [
            MiniMaxModelRemain(modelName: "model-a", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 10, startTime: 0, endTime: 0, remainsTime: 0),
            MiniMaxModelRemain(modelName: "model-b", currentIntervalTotalCount: 200, currentIntervalRemainingCount: 180, startTime: 0, endTime: 0, remainsTime: 0),
        ]
        let alerts = NotificationManager.checkThresholds(models: models)
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts[0].modelName, "model-a")
    }

    func testDeduplicationReturnsOnlyNewAlerts() {
        let model = MiniMaxModelRemain(modelName: "test", currentIntervalTotalCount: 100, currentIntervalRemainingCount: 10, startTime: 0, endTime: 0, remainsTime: 0)

        // First call returns the alert and marks it sent internally
        let firstRun = NotificationManager.checkThresholds(models: [model])
        XCTAssertEqual(firstRun.count, 1)

        // Second call with same usage should be deduplicated
        let secondRun = NotificationManager.checkThresholds(models: [model])
        XCTAssertTrue(secondRun.isEmpty)
    }
}
