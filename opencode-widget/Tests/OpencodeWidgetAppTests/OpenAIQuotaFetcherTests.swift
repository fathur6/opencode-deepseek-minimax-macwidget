import XCTest
@testable import OpencodeWidgetApp

final class OpenAIQuotaFetcherTests: XCTestCase {
    func testFetchParsesHelperJSON() async throws {
        let helper = try makeHelper(script: "printf '{\"remainingPercent\":97,\"resetDate\":\"2026-07-23T00:00:00Z\"}'")
        let result = await OpenAIQuotaFetcher.fetch(
            helperPath: helper,
            usageURL: URL(string: "https://chatgpt.com/usage")!,
            timeout: 2
        )
        XCTAssertEqual(result?.remainingPercent, 97)
        XCTAssertEqual(result?.resetDate, Date(timeIntervalSince1970: 1_784_764_800))
    }

    func testFetchReturnsNilForMalformedJSON() async throws {
        let helper = try makeHelper(script: "printf 'not-json'")
        let result = await OpenAIQuotaFetcher.fetch(
            helperPath: helper,
            usageURL: URL(string: "https://chatgpt.com/usage")!,
            timeout: 2
        )
        XCTAssertNil(result)
    }

    func testFetchReturnsNilForNonzeroExit() async throws {
        let helper = try makeHelper(script: "exit 1")
        let result = await OpenAIQuotaFetcher.fetch(
            helperPath: helper,
            usageURL: URL(string: "https://chatgpt.com/usage")!,
            timeout: 2
        )
        XCTAssertNil(result)
    }

    func testFetchReturnsNilAfterTimeout() async throws {
        let helper = try makeHelper(script: "sleep 2")
        let result = await OpenAIQuotaFetcher.fetch(
            helperPath: helper,
            usageURL: URL(string: "https://chatgpt.com/usage")!,
            timeout: 0.05
        )
        XCTAssertNil(result)
    }

    private func makeHelper(script: String) throws -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("openai-helper-")
            .appendingPathExtension(UUID().uuidString)
            .path
        try "#!/bin/sh\n\(script)\n".write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path)
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }
        return path
    }
}
