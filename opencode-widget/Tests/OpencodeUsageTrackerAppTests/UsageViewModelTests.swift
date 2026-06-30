import XCTest
@testable import OpencodeUsageTrackerApp
@testable import OpencodeWidgetShared

final class UsageViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.responses = [:]
        MockURLProtocol.defaultData = nil
        MockURLProtocol.defaultError = nil
        MockURLProtocol.defaultStatusCode = 200
        NotificationManager.resetAlerts()
    }

    func testInitialStateIsLoading() {
        let vm = UsageViewModel()
        XCTAssertEqual(vm.state, .loading)
    }

    func testLoadWithMissingAuthShowsOnboarding() async {
        let vm = UsageViewModel(authPath: "/nonexistent/auth.json")
        await vm.load()
        XCTAssertEqual(vm.state, .onboarding)
    }

    func testRefreshUpdatesBalances() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let authPath = tmp.appendingPathComponent("test-auth-\(UUID().uuidString).json").path
        let authJSON = """
        {"deepseek": {"key": "ds-test"}, "minimax": {"key": "mm-test"}}
        """
        try authJSON.write(toFile: authPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: authPath) }

        MockURLProtocol.responses = [
            "https://api.deepseek.com/user/balance": ("{\"balance_infos\": [{\"total_balance\": \"42.00\"}]}".data(using: .utf8), nil, 200),
            "https://api.minimax.io/v1/api/openplatform/coding_plan/remains": ("{\"modelRemains\": [], \"baseResp\": {\"statusCode\": 0}}".data(using: .utf8), nil, 200),
        ]

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let vm = UsageViewModel(authPath: authPath)
        await vm.refresh(session: session, dbPath: "/nonexistent/db.db")

        if case .loaded(let data) = vm.state {
            XCTAssertEqual(data.deepseekBalance, 42.00)
        } else {
            XCTFail("Expected loaded state, got \(vm.state)")
        }
    }

    func testRefreshWithNetworkErrorShowsError() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let authPath = tmp.appendingPathComponent("test-auth-\(UUID().uuidString).json").path
        let authJSON = """
        {"deepseek": {"key": "ds-test"}, "minimax": {"key": "mm-test"}}
        """
        try authJSON.write(toFile: authPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: authPath) }

        MockURLProtocol.defaultError = NSError(domain: "test", code: -1, userInfo: nil)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let vm = UsageViewModel(authPath: authPath)
        await vm.refresh(session: session, dbPath: "/nonexistent/db.db")

        if case .error(let message) = vm.state {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected error state, got \(vm.state)")
        }
    }
}
