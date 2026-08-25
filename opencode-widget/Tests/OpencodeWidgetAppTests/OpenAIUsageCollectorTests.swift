import XCTest
import SQLite3
@testable import OpencodeWidgetApp

final class OpenAIUsageCollectorTests: XCTestCase {
    private var root: URL!
    private let now = Date(timeIntervalSince1970: 1_800_000_123)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("openai-usage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        root = nil
    }

    func testHourlyTotalPricesSupportedModelsAndExcludesUnknownModels() {
        let hour = Date(timeIntervalSince1970: 0)
        let samples = [
            OpenAIUsageSample(hour: hour, modelID: "gpt-5.6-terra", inputTokens: 1_000_000, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .openCode, sessionID: "a"),
            OpenAIUsageSample(hour: hour, modelID: "unknown", inputTokens: 1_000_000, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .codex, sessionID: "b")
        ]

        XCTAssertEqual(OpenAIUsageCollector.aggregate(samples)[hour]?.inputTokens, 1_000_000)
        XCTAssertEqual(OpenAIUsageCollector.aggregate(samples)[hour]?.estimatedCostUSD, 2)
    }

    func testDirectCodexSampleWinsOverMirroredHermesSession() {
        let hour = Date(timeIntervalSince1970: 0)
        let codex = OpenAIUsageSample(hour: hour, modelID: "gpt-5.6-luna", inputTokens: 100, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .codex, sessionID: "shared")
        let hermes = OpenAIUsageSample(hour: hour, modelID: "gpt-5.6-luna", inputTokens: 100, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .hermes, sessionID: "shared")

        XCTAssertEqual(OpenAIUsageCollector.aggregate([codex, hermes])[hour]?.inputTokens, 100)
    }

    func testDirectOpenCodeSampleWinsOverMirroredHermesSession() {
        let hour = Date(timeIntervalSince1970: 0)
        let openCode = OpenAIUsageSample(hour: hour, modelID: "gpt-5.6-luna", inputTokens: 100, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .openCode, sessionID: "shared")
        let hermes = OpenAIUsageSample(hour: hour, modelID: "gpt-5.6-luna", inputTokens: 100, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .hermes, sessionID: "shared")

        XCTAssertEqual(OpenAIUsageCollector.aggregate([openCode, hermes])[hour]?.inputTokens, 100)
    }

    func testHourlyTotalsAreUnavailableWhenOpenCodeSourceIsMissing() throws {
        let collector = try makeCollector(openCodePath: root.appendingPathComponent("missing-opencode.db").path)

        XCTAssertNil(collector.hourlyTotals())
    }

    func testHourlyTotalsAreUnavailableWhenCodexSourceIsMissing() throws {
        let collector = try makeCollector(codexRoots: [root.appendingPathComponent("missing-codex")])

        XCTAssertNil(collector.hourlyTotals())
    }

    func testHourlyTotalsAreUnavailableWhenHermesSourceIsMissing() throws {
        let collector = try makeCollector(hermesPath: root.appendingPathComponent("missing-hermes.db").path)

        XCTAssertNil(collector.hourlyTotals())
    }

    func testHourlyTotalsAreUnavailableWhenCodexSessionFileCannotBeRead() throws {
        let codexRoot = root.appendingPathComponent("codex")
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try Data([0xFF]).write(to: codexRoot.appendingPathComponent("session.jsonl"))
        let collector = try makeCollector(codexRoots: [codexRoot])

        XCTAssertNil(collector.hourlyTotals())
    }

    private func makeCollector(
        openCodePath: String? = nil,
        hermesPath: String? = nil,
        codexRoots: [URL]? = nil
    ) throws -> OpenAIUsageCollector {
        let openCode = root.appendingPathComponent("opencode.db")
        let hermes = root.appendingPathComponent("hermes.db")
        try makeDatabase(at: openCode, statements: [
            "CREATE TABLE message (time_created INTEGER, session_id TEXT, data TEXT)"
        ])
        try makeDatabase(at: hermes, statements: [
            "CREATE TABLE session_model_usage (last_seen INTEGER, session_id TEXT, model TEXT, input_tokens INTEGER, cache_read_tokens INTEGER, cache_write_tokens INTEGER, output_tokens INTEGER, billing_provider TEXT)"
        ])
        let codex = root.appendingPathComponent("codex-empty")
        try FileManager.default.createDirectory(at: codex, withIntermediateDirectories: true)
        return OpenAIUsageCollector(
            now: now,
            openCodeDatabasePath: openCodePath ?? openCode.path,
            hermesDatabasePath: hermesPath ?? hermes.path,
            codexRoots: codexRoots ?? [codex]
        )
    }

    private func makeDatabase(at url: URL, statements: [String]) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }
        for statement in statements {
            XCTAssertEqual(sqlite3_exec(database, statement, nil, nil, nil), SQLITE_OK)
        }
    }
}
