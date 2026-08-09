import Foundation
import XCTest
@testable import OpencodeWidgetApp
@testable import OpencodeWidgetShared

private final class QuotaMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class OpenAIQuotaFetcherTests: XCTestCase {
    private let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    override func setUp() {
        super.setUp()
        QuotaMockURLProtocol.responseData = Data()
        QuotaMockURLProtocol.statusCode = 200
        QuotaMockURLProtocol.lastRequest = nil
    }

    func testFetchParsesWeeklyWindowAndSendsOAuthHeaders() async {
        QuotaMockURLProtocol.responseData = Data(#"""
          {
            "plan_type": "plus",
            "rate_limit": {
              "primary_window": {"used_percent": 10, "reset_at": 1784764800},
              "secondary_window": {"used_percent": 3, "reset_at": 1784808960}
            }
          }
        """#.utf8)
        let session = makeSession()
        let credentials = OpenAIAuthCredentials(accessToken: "test-token", accountID: "acct-test")

        let result = await OpenAIQuotaFetcher.fetch(credentials: credentials, session: session, endpoint: endpoint)

        XCTAssertEqual(result?.remainingPercent, 97)
        XCTAssertEqual(result?.resetDate, Date(timeIntervalSince1970: 1784808960))
        XCTAssertEqual(QuotaMockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        XCTAssertEqual(QuotaMockURLProtocol.lastRequest?.value(forHTTPHeaderField: "ChatGPT-Account-ID"), "acct-test")
    }

    func testFetchFallsBackToPrimaryWindowWhenWeeklyWindowMissing() async {
        QuotaMockURLProtocol.responseData = Data(#"""
          {
            "rate_limit": {"primary_window": {"used_percent": 25, "reset_at": 1784764800}}
          }
        """#.utf8)

        let result = await OpenAIQuotaFetcher.fetch(
            credentials: OpenAIAuthCredentials(accessToken: "test-token"),
            session: makeSession(),
            endpoint: endpoint
        )

        XCTAssertEqual(result?.remainingPercent, 75)
    }

    func testFetchReturnsNilForUnauthorizedResponse() async {
        QuotaMockURLProtocol.statusCode = 401
        QuotaMockURLProtocol.responseData = Data(#"{"error":"token_expired"}"#.utf8)

        let result = await OpenAIQuotaFetcher.fetch(
            credentials: OpenAIAuthCredentials(accessToken: "expired-token"),
            session: makeSession(),
            endpoint: endpoint
        )

        XCTAssertNil(result)
    }

    func testFetchReturnsNilForMalformedOrMissingUsage() async {
        QuotaMockURLProtocol.responseData = Data(#"{"rate_limit": {}}"#.utf8)

        let result = await OpenAIQuotaFetcher.fetch(
            credentials: OpenAIAuthCredentials(accessToken: "test-token"),
            session: makeSession(),
            endpoint: endpoint
        )

        XCTAssertNil(result)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QuotaMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
