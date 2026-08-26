import Foundation
import SQLite3

struct DeepSeekHourlyTotal: Sendable, Equatable {
    let inputTokens: Int
}

struct DeepSeekUsageSample: Sendable {
    let hour: Date
    let inputTokens: Int64

    init(hour: Date, inputTokens: Int64) {
        self.hour = Date(timeIntervalSince1970: floor(hour.timeIntervalSince1970 / 3_600) * 3_600)
        self.inputTokens = inputTokens
    }
}

/// Aggregates the per-hour DeepSeek input usage used by the ledger's
/// `deepseek_input_tokens` column, so the Usage chart reads DeepSeek data from
/// the single ledger. It mirrors the DeepSeek event queries in
/// `UsageHistoryFetcher` but returns `nil` when a configured source cannot be
/// read, so an unavailable source does not replace a complete prior hour.
struct DeepSeekUsageCollector: Sendable {
    let now: Date
    let openCodeDatabasePath: String
    let hermesDatabasePath: String
    private let databaseStep: @Sendable (OpaquePointer?) -> Int32

    init(
        now: Date = Date(),
        openCodeDatabasePath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db",
        hermesDatabasePath: String = "\(NSHomeDirectory())/.hermes/state.db",
        databaseStep: @escaping @Sendable (OpaquePointer?) -> Int32 = sqlite3_step
    ) {
        self.now = now
        self.openCodeDatabasePath = openCodeDatabasePath
        self.hermesDatabasePath = hermesDatabasePath
        self.databaseStep = databaseStep
    }

    func hourlyTotals() -> [Date: DeepSeekHourlyTotal]? {
        let openCode = readOpenCode()
        let hermes = readHermes()
        guard openCode.readable, hermes.readable else { return nil }
        return Self.aggregate(openCode.samples + hermes.samples)
    }

    static func aggregate(_ samples: [DeepSeekUsageSample]) -> [Date: DeepSeekHourlyTotal] {
        var totals: [Date: DeepSeekHourlyTotal] = [:]
        for sample in samples {
            let tokens = max(0, sample.inputTokens)
            let previous = totals[sample.hour] ?? DeepSeekHourlyTotal(inputTokens: 0)
            totals[sample.hour] = DeepSeekHourlyTotal(inputTokens: previous.inputTokens + Int(tokens))
        }
        return totals
    }

    private typealias SourceRead = (samples: [DeepSeekUsageSample], readable: Bool)

    private func readOpenCode() -> SourceRead {
        readDatabase(path: openCodeDatabasePath, query: """
            SELECT time_created,
                   COALESCE(json_extract(data, '$.tokens.input'), 0) +
                   COALESCE(json_extract(data, '$.tokens.cache.read'), 0) +
                   COALESCE(json_extract(data, '$.tokens.cache.write'), 0)
            FROM message
            WHERE json_valid(data)
              AND json_extract(data, '$.role') = 'assistant'
              AND json_extract(data, '$.providerID') = 'deepseek'
              AND time_created >= ? AND time_created <= ?
            """, cutoff: Int64(cutoff.timeIntervalSince1970 * 1_000), timestampDivisor: 1_000)
    }

    private func readHermes() -> SourceRead {
        readDatabase(path: hermesDatabasePath, query: """
            SELECT last_seen,
                   COALESCE(input_tokens, 0) + COALESCE(cache_read_tokens, 0) + COALESCE(cache_write_tokens, 0)
            FROM session_model_usage
              WHERE billing_provider = 'deepseek'
              AND last_seen >= ? AND last_seen <= ?
            """, cutoff: Int64(cutoff.timeIntervalSince1970), timestampDivisor: 1)
    }

    private func readDatabase(path: String, query: String, cutoff: Int64, timestampDivisor: Double) -> SourceRead {
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
        sqlite3_bind_int64(statement, 2, Int64(now.timeIntervalSince1970 * timestampDivisor))

        var samples: [DeepSeekUsageSample] = []
        var stepResult: Int32
        repeat {
            stepResult = databaseStep(statement)
            guard stepResult == SQLITE_ROW else { break }
            let timestamp = Double(sqlite3_column_int64(statement, 0)) / timestampDivisor
            guard timestamp.isFinite else { continue }
            let tokenValue = sqlite3_column_double(statement, 1)
            guard tokenValue.isFinite, tokenValue >= 0 else { continue }
            samples.append(DeepSeekUsageSample(hour: Date(timeIntervalSince1970: timestamp), inputTokens: Int64(tokenValue.rounded())))
        } while stepResult == SQLITE_ROW
        return (samples, stepResult == SQLITE_DONE)
    }

    private var cutoff: Date {
        let endHour = floor(now.timeIntervalSince1970 / 3_600) * 3_600
        return Date(timeIntervalSince1970: endHour - Double(UsageHistoryFetcher.bucketCount - 1) * 3_600)
    }
}
