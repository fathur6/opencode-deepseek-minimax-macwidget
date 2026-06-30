import XCTest
@testable import OpencodeUsageTrackerApp
@testable import OpencodeWidgetShared

final class MiniMaxAPIServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.responses = [:]
        MockURLProtocol.defaultData = nil
        MockURLProtocol.defaultError = nil
        MockURLProtocol.defaultStatusCode = 200
    }

    func testFetchReturnsModelRemainsOnSuccess() async throws {
        let json = """
        {"modelRemains": [
            {"modelName": "minimax-v1", "currentIntervalTotalCount": 200, "currentIntervalRemainingCount": 145, "startTime": 1700000000000, "endTime": 1702592000000, "remainsTime": 259200000}
        ], "baseResp": {"statusCode": 0}}
        """
        MockURLProtocol.defaultData = json.data(using: .utf8)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let models = try await MiniMaxAPIService.fetchUsage(apiKey: "test-key", session: session)
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models[0].modelName, "minimax-v1")
        XCTAssertEqual(models[0].currentIntervalTotalCount, 200)
        XCTAssertEqual(models[0].currentIntervalRemainingCount, 145)
    }

    func testFetchReturnsMultipleModels() async throws {
        let json = """
        {"modelRemains": [
            {"modelName": "model-a", "currentIntervalTotalCount": 100, "currentIntervalRemainingCount": 80, "startTime": 1700000000000, "endTime": 1702592000000, "remainsTime": 259200000},
            {"modelName": "model-b", "currentIntervalTotalCount": 200, "currentIntervalRemainingCount": 150, "startTime": 1700000000000, "endTime": 1702592000000, "remainsTime": 259200000}
        ], "baseResp": {"statusCode": 0}}
        """
        MockURLProtocol.defaultData = json.data(using: .utf8)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let models = try await MiniMaxAPIService.fetchUsage(apiKey: "test-key", session: session)
        XCTAssertEqual(models.count, 2)
    }

    func testFetchThrowsOnNetworkError() async {
        MockURLProtocol.defaultError = NSError(domain: "test", code: -1)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        await XCTAssertThrowsError(try await MiniMaxAPIService.fetchUsage(apiKey: "test-key", session: session))
    }

    func testFetchThrowsOnHTTPError() async {
        MockURLProtocol.defaultStatusCode = 401

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        await XCTAssertThrowsError(try await MiniMaxAPIService.fetchUsage(apiKey: "test-key", session: session))
    }
}
