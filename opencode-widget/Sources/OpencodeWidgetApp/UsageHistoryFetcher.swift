import Foundation
import SQLite3
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

enum UsageProvider: Sendable {
    case openAI
    case deepseek
}

struct UsageTokenEvent: Sendable {
    let provider: UsageProvider
    let timestamp: Date
    let inputTokens: Int64
}

struct UsageHistoryResult: Sendable {
    let buckets: [HourlyUsageBucket]
    let anySourceReadable: Bool
}

/// Assembles local client histories additively. Hermes rows are cumulative
/// backfill attributed to `last_seen`, not exact per-request timestamps.
struct UsageHistoryFetcher: Sendable {
    static let bucketCount = DeepSeekBalanceHistory.maximumHours

    let now: Date
    let openCodeDatabasePath: String
    let hermesDatabasePath: String
    let codexRoots: [URL]

    init(
        now: Date = Date(),
        openCodeDatabasePath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db",
        hermesDatabasePath: String = "\(NSHomeDirectory())/.hermes/state.db",
        codexRoots: [URL] = [
            URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/sessions", isDirectory: true),
            URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/archived_sessions", isDirectory: true)
        ]
    ) {
        self.now = now
        self.openCodeDatabasePath = openCodeDatabasePath
        self.hermesDatabasePath = hermesDatabasePath
        self.codexRoots = codexRoots
    }

    func fetch() -> UsageHistoryResult {
        let openCode = readOpenCode()
        let hermes = readHermes()
        let events = openCode.events + hermes.events
        return UsageHistoryResult(
            buckets: Self.makeBuckets(events: events, now: now),
            anySourceReadable: openCode.readable || hermes.readable
        )
    }

    static func makeBuckets(events: [UsageTokenEvent], now: Date) -> [HourlyUsageBucket] {
        let endHour = floor(now.timeIntervalSince1970 / 3_600) * 3_600
        let firstHour = endHour - Double(bucketCount - 1) * 3_600
        var openAI = Array(repeating: Int64(0), count: bucketCount)
        var deepseek = Array(repeating: Int64(0), count: bucketCount)

        for event in events where event.timestamp <= now && event.inputTokens >= 0 {
            let eventHour = floor(event.timestamp.timeIntervalSince1970 / 3_600) * 3_600
            let index = Int((eventHour - firstHour) / 3_600)
            guard (0..<bucketCount).contains(index) else { continue }
            switch event.provider {
            case .openAI: openAI[index] += event.inputTokens
            case .deepseek: deepseek[index] += event.inputTokens
            }
        }

        return (0..<bucketCount).map { index in
            let start = max(0, index - 2)
            let count = Double(index - start + 1)
            let smoothedOpenAI = Double(openAI[start...index].reduce(0, +)) / count
            let smoothedDeepseek = Double(deepseek[start...index].reduce(0, +)) / count
            return HourlyUsageBucket(
                hour: Date(timeIntervalSince1970: firstHour + Double(index) * 3_600),
                openAIInputTokens: openAI[index],
                deepseekInputTokens: deepseek[index],
                smoothedOpenAIInputTokens: smoothedOpenAI,
                smoothedDeepseekInputTokens: smoothedDeepseek
            )
        }
    }

    private typealias SourceRead = (events: [UsageTokenEvent], readable: Bool)

    private func readOpenCode() -> SourceRead {
        readDatabase(path: openCodeDatabasePath, query: """
            SELECT time_created,
                    'deepseek',
                   COALESCE(json_extract(data, '$.tokens.input'), 0) +
                   COALESCE(json_extract(data, '$.tokens.cache.read'), 0) +
                   COALESCE(json_extract(data, '$.tokens.cache.write'), 0)
            FROM message
            WHERE json_valid(data)
              AND json_extract(data, '$.role') = 'assistant'
              AND json_extract(data, '$.providerID') = 'deepseek'
              AND time_created >= ? AND time_created <= ?
            """, cutoff: Int64(cutoff.timeIntervalSince1970 * 1_000), upper: Int64(now.timeIntervalSince1970 * 1_000), timestampDivisor: 1_000) { value in
                value == "deepseek" ? .deepseek : nil
            }
    }

    private func readHermes() -> SourceRead {
        readDatabase(path: hermesDatabasePath, query: """
            SELECT last_seen, 'deepseek',
                   COALESCE(input_tokens, 0) + COALESCE(cache_read_tokens, 0) + COALESCE(cache_write_tokens, 0)
            FROM session_model_usage
              WHERE billing_provider = 'deepseek'
              AND last_seen >= ? AND last_seen <= ?
            """, cutoff: Int64(cutoff.timeIntervalSince1970), upper: Int64(now.timeIntervalSince1970), timestampDivisor: 1) { value in
                value == "deepseek" ? .deepseek : nil
            }
    }

    private func readDatabase(
        path: String,
        query: String,
        cutoff: Int64,
        upper: Int64,
        timestampDivisor: Double,
        provider: (String) -> UsageProvider?
    ) -> SourceRead {
        guard FileManager.default.fileExists(atPath: path) else { return ([], false) }
        var database: OpaquePointer?
        guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database else {
            sqlite3_close(database)
            return ([], false)
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            sqlite3_finalize(statement)
            return ([], false)
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, cutoff)
        sqlite3_bind_int64(statement, 2, upper)

        var events: [UsageTokenEvent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let providerText = sqlite3_column_text(statement, 1),
                  let mappedProvider = provider(String(cString: providerText)) else { continue }
            let timestamp = Double(sqlite3_column_int64(statement, 0)) / timestampDivisor
            let tokenValue = sqlite3_column_double(statement, 2)
            guard timestamp.isFinite, tokenValue.isFinite, tokenValue >= 0 else { continue }
            events.append(UsageTokenEvent(
                provider: mappedProvider,
                timestamp: Date(timeIntervalSince1970: timestamp),
                inputTokens: Int64(tokenValue.rounded())
            ))
        }
        return (events, true)
    }

    private var cutoff: Date {
        let endHour = floor(now.timeIntervalSince1970 / 3_600) * 3_600
        return Date(timeIntervalSince1970: endHour - Double(Self.bucketCount - 1) * 3_600)
    }

}
