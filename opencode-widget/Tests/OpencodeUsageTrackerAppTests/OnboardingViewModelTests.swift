import XCTest
@testable import OpencodeUsageTrackerApp
@testable import OpencodeWidgetShared

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.responses = [:]
        MockURLProtocol.defaultData = nil
        MockURLProtocol.defaultError = nil
        MockURLProtocol.defaultStatusCode = 200
    }

    func testInitialState() async {
        let vm = OnboardingViewModel()
        XCTAssertTrue(vm.deepseekKey.isEmpty)
        XCTAssertTrue(vm.minimaxKey.isEmpty)
        XCTAssertTrue(vm.statusMessage.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }

    func testVerifyAndSaveWithEmptyKeysDoesNothing() async {
        let vm = OnboardingViewModel()
        var called = false
        await vm.verifyAndSave(onComplete: { called = true })
        XCTAssertFalse(called)
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.statusMessage.isEmpty)
    }

    func testVerifyAndSaveWithValidKeysSavesAuthAndCallsOnComplete() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let authPath = tmp.appendingPathComponent("test-onboarding-\(UUID().uuidString).json").path
        defer { try? FileManager.default.removeItem(atPath: authPath) }

        MockURLProtocol.responses = [
            "https://api.deepseek.com/user/balance": ("{\"balance_infos\": [{\"total_balance\": \"42.00\"}]}".data(using: .utf8), nil, 200),
            "https://api.minimax.io/v1/api/openplatform/coding_plan/remains": ("{\"modelRemains\": [], \"baseResp\": {\"statusCode\": 0}}".data(using: .utf8), nil, 200),
        ]

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let vm = OnboardingViewModel(authPath: authPath)
        vm.deepseekKey = "ds-test"
        vm.minimaxKey = "mm-test"

        var called = false
        await vm.verifyAndSave(session: session, onComplete: { called = true })

        XCTAssertTrue(called)
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.statusMessage.isEmpty)

        let creds = AuthReader.readCredentials(authPath: authPath)
        XCTAssertNotNil(creds)
        XCTAssertEqual(creds?.deepseekKey, "ds-test")
        XCTAssertEqual(creds?.minimaxKey, "mm-test")
    }

    func testVerifyAndSaveWithDeepSeekErrorShowsError() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let authPath = tmp.appendingPathComponent("test-onboarding-\(UUID().uuidString).json").path
        defer { try? FileManager.default.removeItem(atPath: authPath) }

        MockURLProtocol.defaultError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "network error"])

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let vm = OnboardingViewModel(authPath: authPath)
        vm.deepseekKey = "ds-test"
        vm.minimaxKey = "mm-test"

        var called = false
        await vm.verifyAndSave(session: session, onComplete: { called = true })

        XCTAssertFalse(called)
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.statusMessage.contains("DeepSeek"))

        let creds = AuthReader.readCredentials(authPath: authPath)
        XCTAssertNil(creds)
    }

    func testVerifyAndSaveWithMiniMaxErrorAfterSuccessfulDeepSeekShowsError() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let authPath = tmp.appendingPathComponent("test-onboarding-\(UUID().uuidString).json").path
        defer { try? FileManager.default.removeItem(atPath: authPath) }

        MockURLProtocol.responses = [
            "https://api.deepseek.com/user/balance": ("{\"balance_infos\": [{\"total_balance\": \"42.00\"}]}".data(using: .utf8), nil, 200),
        ]
        MockURLProtocol.defaultError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "network error"])

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let vm = OnboardingViewModel(authPath: authPath)
        vm.deepseekKey = "ds-test"
        vm.minimaxKey = "mm-test"

        var called = false
        await vm.verifyAndSave(session: session, onComplete: { called = true })

        XCTAssertFalse(called)
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.statusMessage.contains("MiniMax"))

        let creds = AuthReader.readCredentials(authPath: authPath)
        XCTAssertNil(creds)
    }
}
