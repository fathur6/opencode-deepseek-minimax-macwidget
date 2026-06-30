import XCTest
import SQLite3
@testable import OpencodeUsageTrackerApp
@testable import OpencodeWidgetShared

final class DatabaseServiceTests: XCTestCase {
    var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tmp = FileManager.default.temporaryDirectory
        tempDBPath = tmp.appendingPathComponent("testdb-\(UUID().uuidString).db").path
        createDB()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDBPath)
        tempDBPath = nil
        super.tearDown()
    }

    // MARK: - queryUsage

    func testQueryUsageReturnsEmptyForNoData() {
        let rows = DatabaseService.queryUsage(dbPath: tempDBPath)
        XCTAssertTrue(rows.isEmpty)
    }

    func testQueryUsageAggregatesByProvider() {
        insertSession(dayOffset: 0, provider: "deepseek", tokensInput: 100, tokensOutput: 50, cost: 1.5)
        insertSession(dayOffset: 0, provider: "minimax", tokensInput: 200, tokensOutput: 100, cost: 3.0)

        let rows = DatabaseService.queryUsage(dbPath: tempDBPath)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].deepseekTokens, 150)
        XCTAssertEqual(rows[0].minimaxTokens, 300)
    }

    // MARK: - queryPerModelUsage

    func testQueryPerModelUsageReturnsPerModelRows() {
        insertSession(dayOffset: 0, provider: "deepseek", modelId: "deepseek-v4", tokensInput: 100, tokensOutput: 50, cost: 1.5)
        insertSession(dayOffset: 0, provider: "deepseek", modelId: "deepseek-chat", tokensInput: 200, tokensOutput: 0, cost: 2.0)

        let rows = DatabaseService.queryPerModelUsage(dbPath: tempDBPath)
        XCTAssertEqual(rows.count, 2)
        let v4 = rows.first { $0.modelId == "deepseek-v4" }
        let chat = rows.first { $0.modelId == "deepseek-chat" }
        XCTAssertEqual(v4?.tokens, 150)
        XCTAssertEqual(chat?.tokens, 200)
    }

    func testQueryPerModelUsageExcludesNullModel() {
        var db: OpaquePointer?
        guard sqlite3_open(tempDBPath, &db) == SQLITE_OK, let db = db else { return XCTFail() }
        defer { sqlite3_close(db) }

        let timestamp = Int(Date().timeIntervalSince1970)
        let sql = "INSERT INTO session (time_created, model, tokens_input, tokens_output, cost) VALUES (?, NULL, 100, 0, 1.0);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return XCTFail() }
        sqlite3_bind_int64(stmt, 1, sqlite3_int64(timestamp))
        guard sqlite3_step(stmt) == SQLITE_DONE else { XCTFail(); sqlite3_finalize(stmt); return }
        sqlite3_finalize(stmt)

        let rows = DatabaseService.queryPerModelUsage(dbPath: tempDBPath)
        XCTAssertTrue(rows.isEmpty)
    }

    // MARK: - Helpers

    private func createDB() {
        var db: OpaquePointer?
        guard sqlite3_open(tempDBPath, &db) == SQLITE_OK, let db = db else {
            XCTFail("Failed to create temp DB")
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
            sqlite3_free(errMsg)
            XCTFail("Failed to create table")
            return
        }
    }

    private func insertSession(dayOffset: Int, provider: String, modelId: String = "default", tokensInput: Int = 0, tokensOutput: Int = 0, cost: Double = 0) {
        var db: OpaquePointer?
        guard sqlite3_open(tempDBPath, &db) == SQLITE_OK, let db = db else {
            XCTFail("Failed to open DB")
            return
        }
        defer { sqlite3_close(db) }

        let timestamp = Int(Date().timeIntervalSince1970) - dayOffset * 86400
        let modelJSON = "{\"providerID\": \"\(provider)\", \"id\": \"\(modelId)\"}"

        let sql = "INSERT INTO session (time_created, model, tokens_input, tokens_output, cost) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { XCTFail(); return }
        sqlite3_bind_int64(stmt, 1, sqlite3_int64(timestamp))
        sqlite3_bind_text(stmt, 2, (modelJSON as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 3, sqlite3_int64(tokensInput))
        sqlite3_bind_int64(stmt, 4, sqlite3_int64(tokensOutput))
        sqlite3_bind_double(stmt, 5, cost)
        guard sqlite3_step(stmt) == SQLITE_DONE else { XCTFail(); sqlite3_finalize(stmt); return }
        sqlite3_finalize(stmt)
    }
}
