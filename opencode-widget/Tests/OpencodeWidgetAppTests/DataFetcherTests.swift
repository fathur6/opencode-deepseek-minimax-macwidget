import XCTest
import SQLite3
@testable import OpencodeWidgetApp
@testable import OpencodeWidgetShared

class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData: Data?
    nonisolated(unsafe) static var responseError: Error?
    nonisolated(unsafe) static var statusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = Self.responseError {
            client?.urlProtocol(self, didFailWithError: error)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = Self.responseData {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class DataFetcherTests: XCTestCase {
    var tempDBPath: String!
    var tempAuthPath: String!

    override func setUp() {
        super.setUp()
        let tmp = FileManager.default.temporaryDirectory
        let id = UUID().uuidString
        tempDBPath = tmp.appendingPathComponent("testdb-\(id).db").path
        tempAuthPath = tmp.appendingPathComponent("testauth-\(id).json").path
        try? FileManager.default.removeItem(atPath: tempDBPath)
        try? FileManager.default.removeItem(atPath: tempAuthPath)
        MockURLProtocol.responseData = nil
        MockURLProtocol.responseError = nil
        MockURLProtocol.statusCode = 200
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDBPath)
        try? FileManager.default.removeItem(atPath: tempAuthPath)
        tempDBPath = nil
        tempAuthPath = nil
        MockURLProtocol.responseData = nil
        MockURLProtocol.responseError = nil
        super.tearDown()
    }

    // MARK: - fetchDeepseekBalance Tests

    func testFetchDeepseekBalanceReturnsBalanceOnSuccess() async {
        let json = """
        {"balance_infos": [{"total_balance": "99.95"}]}
        """
        MockURLProtocol.responseData = json.data(using: .utf8)
        MockURLProtocol.statusCode = 200

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let balance = await DataFetcher.fetchDeepseekBalance(apiKey: "test-key", session: session)

        XCTAssertEqual(balance, 99.95)
    }

    func testFetchDeepseekBalanceReturnsNilForInvalidJSON() async {
        MockURLProtocol.responseData = "not-json".data(using: .utf8)
        MockURLProtocol.statusCode = 200

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let balance = await DataFetcher.fetchDeepseekBalance(apiKey: "test-key", session: session)

        XCTAssertNil(balance)
    }

    func testFetchDeepseekBalanceReturnsNilForNetworkError() async {
        MockURLProtocol.responseError = NSError(domain: "test", code: -1, userInfo: nil)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let balance = await DataFetcher.fetchDeepseekBalance(apiKey: "test-key", session: session)

        XCTAssertNil(balance)
    }

    // MARK: - queryUsageFromDB Tests

    func testQueryUsageFromDBReturnsEmptyForEmptyTable() {
        createDB()
        let rows = DataFetcher.queryUsageFromDB(dbPath: tempDBPath)
        XCTAssertTrue(rows.isEmpty)
    }

    func testQueryUsageFromDBAggregatesSingleProvider() {
        createDB()
        insertSession(dayOffset: 0, provider: "deepseek", tokensInput: 100, tokensOutput: 50, cost: 1.5, modelString: "{\"providerID\": \"deepseek\"}")

        let rows = DataFetcher.queryUsageFromDB(dbPath: tempDBPath)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].deepseekTokens, 150)
        XCTAssertEqual(rows[0].deepseekCost, 1.5)
        XCTAssertEqual(rows[0].minimaxTokens, 0)
        XCTAssertEqual(rows[0].minimaxCost, 0)
    }

    func testQueryUsageFromDBAggregatesBothProviders() {
        createDB()
        insertSession(dayOffset: 0, provider: "deepseek", tokensInput: 100, tokensOutput: 50, cost: 1.5, modelString: "{\"providerID\": \"deepseek\"}")
        insertSession(dayOffset: 0, provider: "minimax", tokensInput: 200, tokensOutput: 100, cost: 3.0, modelString: "{\"providerID\": \"minimax\"}")

        let rows = DataFetcher.queryUsageFromDB(dbPath: tempDBPath)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].deepseekTokens, 150)
        XCTAssertEqual(rows[0].deepseekCost, 1.5)
        XCTAssertEqual(rows[0].minimaxTokens, 300)
        XCTAssertEqual(rows[0].minimaxCost, 3.0)
    }

    func testQueryUsageFromDBReturnsMultipleDays() {
        createDB()
        insertSession(dayOffset: 0, provider: "deepseek", tokensInput: 100, tokensOutput: 0, cost: 1.0, modelString: "{\"providerID\": \"deepseek\"}")
        insertSession(dayOffset: 1, provider: "minimax", tokensInput: 200, tokensOutput: 0, cost: 2.0, modelString: "{\"providerID\": \"minimax\"}")
        insertSession(dayOffset: 2, provider: "deepseek", tokensInput: 300, tokensOutput: 0, cost: 3.0, modelString: "{\"providerID\": \"deepseek\"}")

        let rows = DataFetcher.queryUsageFromDB(dbPath: tempDBPath)

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.sorted(by: { $0.date < $1.date }), rows)
    }

    func testQueryUsageFromDBExcludesNullModel() {
        createDB()
        insertSession(dayOffset: 0, provider: "deepseek", tokensInput: 100, tokensOutput: 0, cost: 1.0, modelString: nil)

        let rows = DataFetcher.queryUsageFromDB(dbPath: tempDBPath)

        XCTAssertTrue(rows.isEmpty)
    }

    func testQueryUsageFromDBExcludesEmptyModel() {
        createDB()
        insertSession(dayOffset: 0, provider: "deepseek", tokensInput: 100, tokensOutput: 0, cost: 1.0, modelString: "")

        let rows = DataFetcher.queryUsageFromDB(dbPath: tempDBPath)

        XCTAssertTrue(rows.isEmpty)
    }

    // MARK: - refreshAll Tests

    func testRefreshAllReturnsCachedDataWithBalanceAndUsage() async throws {
        let authJSON = """
        {"deepseek": {"key": "ds-test-key"}, "minimax": {"key": "mm-test-key"}}
        """
        try authJSON.write(toFile: tempAuthPath, atomically: true, encoding: .utf8)

        createDB()
        insertSession(dayOffset: 0, provider: "deepseek", tokensInput: 100, tokensOutput: 50, cost: 1.5, modelString: "{\"providerID\": \"deepseek\"}")

        let balanceJSON = """
        {"balance_infos": [{"total_balance": "42.00"}]}
        """
        MockURLProtocol.responseData = balanceJSON.data(using: .utf8)
        MockURLProtocol.statusCode = 200

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let cache = await DataFetcher.refreshAll(dbPath: tempDBPath, authPath: tempAuthPath, session: session)

        XCTAssertEqual(cache.deepseek.balance, 42.00)
        XCTAssertNil(cache.minimax.balance)
        XCTAssertEqual(cache.dailyUsage.count, 1)
        XCTAssertEqual(cache.dailyUsage[0].deepseekTokens, 150)
    }

    func testRefreshAllReturnsUsageOnlyWhenAuthMissing() async throws {
        createDB()
        insertSession(dayOffset: 0, provider: "deepseek", tokensInput: 100, tokensOutput: 50, cost: 1.5, modelString: "{\"providerID\": \"deepseek\"}")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let cache = await DataFetcher.refreshAll(dbPath: tempDBPath, authPath: tempAuthPath, session: session)

        XCTAssertNil(cache.deepseek.balance)
        XCTAssertNil(cache.minimax.balance)
        XCTAssertEqual(cache.dailyUsage.count, 1)
    }

    func testRefreshAllReturnsEmptyCacheWhenNoData() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let cache = await DataFetcher.refreshAll(dbPath: tempDBPath, authPath: tempAuthPath, session: session)

        XCTAssertNil(cache.deepseek.balance)
        XCTAssertNil(cache.minimax.balance)
        XCTAssertTrue(cache.dailyUsage.isEmpty)
    }

    // MARK: - Helpers

    private func createDB() {
        var db: OpaquePointer?
        guard sqlite3_open(tempDBPath, &db) == SQLITE_OK, let db = db else {
            XCTFail("Failed to create temp DB at \(tempDBPath ?? "nil")")
            return
        }
        defer { sqlite3_close(db) }

        let createSQL = """
        CREATE TABLE IF NOT EXISTS session (
            time_created INTEGER,
            model TEXT,
            tokens_input INTEGER,
            tokens_output INTEGER,
            cost REAL
        );
        """
        var errMsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, createSQL, nil, nil, &errMsg) == SQLITE_OK else {
            let msg = errMsg.flatMap { String(cString: $0) } ?? "unknown"
            sqlite3_free(errMsg)
            XCTFail("Failed to create table: \(msg)")
            return
        }
    }

    private func insertSession(dayOffset: Int, provider: String, tokensInput: Int, tokensOutput: Int, cost: Double, modelString: String? = nil) {
        var db: OpaquePointer?
        guard sqlite3_open(tempDBPath, &db) == SQLITE_OK, let db = db else {
            XCTFail("Failed to open temp DB for insert")
            return
        }
        defer { sqlite3_close(db) }

        let timestamp = Int(Date().timeIntervalSince1970) - dayOffset * 86400

        let insertSQL = "INSERT INTO session (time_created, model, tokens_input, tokens_output, cost) VALUES (?, ?, ?, ?, ?);"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare insert")
            return
        }

        sqlite3_bind_int64(statement, 1, sqlite3_int64(timestamp))
        if let model = modelString {
            sqlite3_bind_text(statement, 2, (model as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 2)
        }
        sqlite3_bind_int64(statement, 3, sqlite3_int64(tokensInput))
        sqlite3_bind_int64(statement, 4, sqlite3_int64(tokensOutput))
        sqlite3_bind_double(statement, 5, cost)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            XCTFail("Failed to insert row")
            sqlite3_finalize(statement)
            return
        }
        sqlite3_finalize(statement)
    }
}
