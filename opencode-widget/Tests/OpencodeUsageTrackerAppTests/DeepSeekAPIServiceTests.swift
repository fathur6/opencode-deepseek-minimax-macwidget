import XCTest
@testable import OpencodeUsageTrackerApp

final class DeepSeekAPIServiceTests: XCTestCase {
    func testFetchBalanceReturnsBalanceOnSuccess() async throws {
        let json = """
        {"balance_infos": [{"total_balance": "99.95"}]}
        """
        MockURLProtocol.defaultData = json.data(using: .utf8)
        MockURLProtocol.defaultStatusCode = 200

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let balance = try await DeepSeekAPIService.fetchBalance(apiKey: "test-key", session: session)
        XCTAssertEqual(balance, 99.95)
    }

    func testFetchBalanceThrowsOnNetworkError() async {
        MockURLProtocol.defaultError = NSError(domain: "test", code: -1)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        await XCTAssertThrowsError(try await DeepSeekAPIService.fetchBalance(apiKey: "test-key", session: session))
    }

    func testFetchBalanceThrowsOnBadJSON() async {
        MockURLProtocol.defaultData = "not-json".data(using: .utf8)
        MockURLProtocol.defaultStatusCode = 200

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        await XCTAssertThrowsError(try await DeepSeekAPIService.fetchBalance(apiKey: "test-key", session: session))
    }

    func testFetchBalanceThrowsOnHTTPError() async {
        MockURLProtocol.defaultStatusCode = 401

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        await XCTAssertThrowsError(try await DeepSeekAPIService.fetchBalance(apiKey: "test-key", session: session))
    }
}
