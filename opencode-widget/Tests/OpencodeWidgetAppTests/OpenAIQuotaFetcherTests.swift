import Foundation
import XCTest
@testable import OpencodeWidgetApp
@testable import OpencodeWidgetShared

private final class QuotaMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.requestCount += 1
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
        QuotaMockURLProtocol.requestCount = 0
    }

    func testFetchParsesWeeklyWindowAndSendsOAuthHeaders() async {
        QuotaMockURLProtocol.responseData = Data(#"""
          {
            "plan_type": "plus",
            "rate_limit": {
              "primary_window": {"limit_window_seconds": 18000, "used_percent": 10, "reset_at": 1784764800},
              "secondary_window": {"limit_window_seconds": 604800, "used_percent": 3, "reset_at": 1784808960}
            }
          }
        """#.utf8)
        let session = makeSession()
        let credentials = OpenAIAuthCredentials(accessToken: "test-token", accountID: "acct-test")

        let result = await OpenAIQuotaFetcher.fetch(credentials: credentials, session: session, endpoint: endpoint)

        XCTAssertEqual(result?.remainingPercent, 97)
        XCTAssertEqual(result?.resetDate, Date(timeIntervalSince1970: 1784808960))
        XCTAssertEqual(result?.fiveHourRemainingPercent, 90)
        XCTAssertEqual(QuotaMockURLProtocol.requestCount, 1)
        XCTAssertEqual(QuotaMockURLProtocol.lastRequest?.timeoutInterval, 10)
        XCTAssertEqual(QuotaMockURLProtocol.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(QuotaMockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        XCTAssertEqual(QuotaMockURLProtocol.lastRequest?.value(forHTTPHeaderField: "ChatGPT-Account-ID"), "acct-test")
    }

    func testFetchRecognizesWeeklyPrimaryByDuration() async {
        QuotaMockURLProtocol.responseData = Data(#"""
          {
            "rate_limit": {"primary_window": {"limit_window_seconds": 604800, "used_percent": 25, "reset_at": 1784764800}}
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

    func testUnknownDurationMustNotBecomeWeekly() async {
        QuotaMockURLProtocol.responseData = Data(#"{"rate_limit":{"primary_window":{"used_percent":25,"reset_at":1784764800}}}"#.utf8)
        let result = await OpenAIQuotaFetcher.fetch(credentials: OpenAIAuthCredentials(accessToken: "fixture"), session: makeSession())
        XCTAssertNil(result)
    }

    func testMalformedSecondaryMustNotDiscardWeeklyPrimary() async {
        QuotaMockURLProtocol.responseData = Data(#"{"rate_limit":{"primary_window":{"limit_window_seconds":604800,"used_percent":25},"secondary_window":"invalid"}}"#.utf8)
        let result = await OpenAIQuotaFetcher.fetch(credentials: OpenAIAuthCredentials(accessToken: "fixture"), session: makeSession())
        XCTAssertEqual(result?.remainingPercent, 75)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QuotaMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func fetchWindows(_ primary: String, _ secondary: String = "null") async -> OpenAIQuota? {
        QuotaMockURLProtocol.responseData = Data("{\"rate_limit\":{\"primary_window\":\(primary),\"secondary_window\":\(secondary)}}".utf8)
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        return await OpenAIQuotaFetcher.fetch(credentials: OpenAIAuthCredentials(accessToken: "fixture"), session: session)
    }

    func testBothOrderingsAndSingleWindows() async {
        let five = #"{"limit_window_seconds":18000,"used_percent":12.5,"reset_at":1784764800.5}"#
        let week = #"{"limit_window_seconds":604800,"used_percent":100,"reset_at":1784808960}"#
        let expected = OpenAIQuota(remainingPercent: 0, resetDate: Date(timeIntervalSince1970: 1784808960), fiveHourRemainingPercent: 87.5, fiveHourResetDate: Date(timeIntervalSince1970: 1784764800.5))
        let normal = await fetchWindows(five, week)
        let reversed = await fetchWindows(week, five)
        XCTAssertEqual(normal, expected)
        XCTAssertEqual(reversed, expected)
        let onlyFive = await fetchWindows(five)
        XCTAssertNil(onlyFive?.remainingPercent)
        XCTAssertNil(onlyFive?.resetDate)
        XCTAssertEqual(onlyFive?.fiveHourRemainingPercent, 87.5)
        let onlyWeek = await fetchWindows("null", week)
        XCTAssertEqual(onlyWeek?.remainingPercent, 0)
        XCTAssertNil(onlyWeek?.fiveHourRemainingPercent)
    }

    func testInvalidWindowsDoNotPoisonEitherSibling() async {
        let invalid = ["null", "[]", "42", #""bad""#, "{}",
            #"{"limit_window_seconds":null,"used_percent":5}"#,
            #"{"limit_window_seconds":"18000","used_percent":5}"#,
            #"{"limit_window_seconds":true,"used_percent":5}"#,
            #"{"limit_window_seconds":18001,"used_percent":5}"#,
            #"{"limit_window_seconds":18000.5,"used_percent":5}"#,
            #"{"limit_window_seconds":1e309,"used_percent":5}"#,
            #"{"limit_window_seconds":18000}"#,
            #"{"limit_window_seconds":18000,"used_percent":null}"#,
            #"{"limit_window_seconds":18000,"used_percent":"5"}"#,
            #"{"limit_window_seconds":18000,"used_percent":true}"#,
            #"{"limit_window_seconds":18000,"used_percent":1e309}"#,
            #"{"limit_window_seconds":18000,"used_percent":-1}"#,
            #"{"limit_window_seconds":18000,"used_percent":101}"#]
        for bad in invalid {
            for duration in [18000, 604800] {
                let valid = "{\"limit_window_seconds\":\(duration),\"used_percent\":0}"
                for (primary, secondary) in [(bad, valid), (valid, bad)] {
                    let result = await fetchWindows(primary, secondary)
                    XCTAssertEqual(duration == 18000 ? result?.fiveHourRemainingPercent : result?.remainingPercent, 100, bad)
                }
            }
            let absent = await fetchWindows(bad)
            XCTAssertNil(absent, bad)
        }
    }

    func testBadResetKeepsValidPercentageWithoutInventingDate() async {
        for reset in ["null", "0", "-1", "1e100", "1e309", "true", #""1784764800""#, "{}", "[]"] {
            let result = await fetchWindows("{\"limit_window_seconds\":18000,\"used_percent\":20,\"reset_at\":\(reset)}", #"{"limit_window_seconds":604800,"used_percent":30,"reset_at":1784808960}"#)
            XCTAssertEqual(result?.fiveHourRemainingPercent, 80, reset)
            XCTAssertNil(result?.fiveHourResetDate, reset)
            XCTAssertEqual(result?.remainingPercent, 70, reset)
            XCTAssertEqual(result?.resetDate, Date(timeIntervalSince1970: 1784808960))
        }
    }

    func testDuplicateDurationUsesFirstValidQuotaEvenWithoutReset() async {
        let first = #"{"limit_window_seconds":18000,"used_percent":20}"#
        let second = #"{"limit_window_seconds":18000,"used_percent":40,"reset_at":1784764800}"#
        let result = await fetchWindows(first, second)
        XCTAssertEqual(result?.fiveHourRemainingPercent, 80)
        XCTAssertNil(result?.fiveHourResetDate)
        let recovered = await fetchWindows(#"{"limit_window_seconds":18000,"used_percent":"bad"}"#, second)
        XCTAssertEqual(recovered?.fiveHourRemainingPercent, 60)
    }

    func testInvalidJSONAndHTTPFailuresReturnNil() async {
        for (status, body) in [(200, "not-json"), (200, "{\"rate_limit\":[]}"), (403, "{}"), (500, "{}"), (200, "{\"rate_limit\":null}")] {
            QuotaMockURLProtocol.statusCode = status
            QuotaMockURLProtocol.responseData = Data(body.utf8)
            let result = await OpenAIQuotaFetcher.fetch(credentials: OpenAIAuthCredentials(accessToken: "fixture"), session: makeSession())
            XCTAssertNil(result)
        }
    }
}
