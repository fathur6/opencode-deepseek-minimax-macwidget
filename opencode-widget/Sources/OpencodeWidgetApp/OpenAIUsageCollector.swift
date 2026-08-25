import Foundation
import SQLite3

enum OpenAIUsageSource: Sendable, Equatable {
    case openCode
    case codex
    case hermes
}

struct OpenAIUsageSample: Sendable {
    let hour: Date
    let modelID: String
    let inputTokens: Int64
    let cachedInputTokens: Int64
    let cacheWriteTokens: Int64
    let outputTokens: Int64
    let source: OpenAIUsageSource
    let sessionID: String

    init(hour: Date, modelID: String, inputTokens: Int64, cachedInputTokens: Int64, cacheWriteTokens: Int64, outputTokens: Int64, source: OpenAIUsageSource, sessionID: String) {
        self.hour = Date(timeIntervalSince1970: floor(hour.timeIntervalSince1970 / 3_600) * 3_600)
        self.modelID = modelID
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.outputTokens = outputTokens
        self.source = source
        self.sessionID = sessionID
    }
}

struct OpenAIHourlyTotal: Sendable, Equatable {
    let inputTokens: Int
    let estimatedCostUSD: Double
}

struct OpenAIUsageCollector: Sendable {
    private static let rates: [String: (Double, Double, Double, Double)] = [
        "gpt-5.6-sol": (4.00, 0.40, 5.00, 20.00),
        "gpt-5.6-terra": (2.00, 0.20, 2.50, 12.00),
        "gpt-5.6-luna": (0.20, 0.02, 0.25, 1.20),
    ]

    let now: Date
    let openCodeDatabasePath: String
    let hermesDatabasePath: String
    let codexRoots: [URL]
    private let codexSessionFiles: @Sendable (URL) -> [URL]?
    private let databaseStep: @Sendable (OpaquePointer?) -> Int32

    init(
        now: Date = Date(),
        openCodeDatabasePath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db",
        hermesDatabasePath: String = "\(NSHomeDirectory())/.hermes/state.db",
        codexRoots: [URL] = [
            URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/sessions", isDirectory: true),
            URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/archived_sessions", isDirectory: true)
        ],
        codexSessionFiles: @escaping @Sendable (URL) -> [URL]? = { root in
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return nil }
            return enumerator.compactMap { $0 as? URL }
        },
        databaseStep: @escaping @Sendable (OpaquePointer?) -> Int32 = sqlite3_step
    ) {
        self.now = now
        self.openCodeDatabasePath = openCodeDatabasePath
        self.hermesDatabasePath = hermesDatabasePath
        self.codexRoots = codexRoots
        self.codexSessionFiles = codexSessionFiles
        self.databaseStep = databaseStep
    }

    func hourlyTotals() -> [Date: OpenAIHourlyTotal]? {
        let openCode = readOpenCode()
        let codex = readCodex()
        let hermes = readHermes()
        guard openCode.readable, codex.readable, hermes.readable else { return nil }

        let directSessionIDs = Set((openCode.samples + codex.samples).map(\.sessionID).filter { !$0.isEmpty })
        return Self.aggregate(openCode.samples + codex.samples + hermes.samples.filter { !directSessionIDs.contains($0.sessionID) })
    }

    static func aggregate(_ samples: [OpenAIUsageSample]) -> [Date: OpenAIHourlyTotal] {
        var totals: [Date: OpenAIHourlyTotal] = [:]
        let directSessionIDs = Set(samples.filter { $0.source != .hermes }.map(\.sessionID).filter { !$0.isEmpty })

        for sample in samples {
            guard sample.source != .hermes || !directSessionIDs.contains(sample.sessionID),
                  let rates = rates[sample.modelID] else { continue }
            let inputTokens = max(0, sample.inputTokens)
            let cachedInputTokens = max(0, sample.cachedInputTokens)
            let cacheWriteTokens = max(0, sample.cacheWriteTokens)
            let outputTokens = max(0, sample.outputTokens)
            let cost = (Double(inputTokens) * rates.0 + Double(cachedInputTokens) * rates.1 + Double(cacheWriteTokens) * rates.2 + Double(outputTokens) * rates.3) / 1_000_000
            let previous = totals[sample.hour] ?? OpenAIHourlyTotal(inputTokens: 0, estimatedCostUSD: 0)
            totals[sample.hour] = OpenAIHourlyTotal(inputTokens: previous.inputTokens + Int(inputTokens), estimatedCostUSD: previous.estimatedCostUSD + cost)
        }
        return totals
    }

    private typealias SourceRead = (samples: [OpenAIUsageSample], readable: Bool)

    private func readOpenCode() -> SourceRead {
        readDatabase(path: openCodeDatabasePath, query: """
            SELECT time_created, session_id, json_extract(data, '$.modelID'),
                   COALESCE(json_extract(data, '$.tokens.input'), 0),
                   COALESCE(json_extract(data, '$.tokens.cache.read'), 0),
                   COALESCE(json_extract(data, '$.tokens.cache.write'), 0),
                   COALESCE(json_extract(data, '$.tokens.output'), 0)
            FROM message
            WHERE json_valid(data)
              AND json_extract(data, '$.role') = 'assistant'
              AND json_extract(data, '$.providerID') = 'openai'
              AND time_created >= ? AND time_created <= ?
            """, cutoff: Int64(cutoff.timeIntervalSince1970 * 1_000), timestampDivisor: 1_000, source: .openCode)
    }

    private func readHermes() -> SourceRead {
        readDatabase(path: hermesDatabasePath, query: """
            SELECT last_seen, session_id, model,
                   COALESCE(input_tokens, 0), COALESCE(cache_read_tokens, 0),
                   COALESCE(cache_write_tokens, 0), COALESCE(output_tokens, 0)
            FROM session_model_usage
            WHERE billing_provider = 'openai-codex'
              AND last_seen >= ? AND last_seen <= ?
            """, cutoff: Int64(cutoff.timeIntervalSince1970), timestampDivisor: 1, source: .hermes)
    }

    private func readDatabase(path: String, query: String, cutoff: Int64, timestampDivisor: Double, source: OpenAIUsageSource) -> SourceRead {
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

        var samples: [OpenAIUsageSample] = []
        var stepResult: Int32
        repeat {
            stepResult = databaseStep(statement)
            guard stepResult == SQLITE_ROW else { break }
            let timestamp = Double(sqlite3_column_int64(statement, 0)) / timestampDivisor
            guard timestamp.isFinite,
                  let modelText = sqlite3_column_text(statement, 2) else { continue }
            let tokens = (3...6).map { Int64(sqlite3_column_double(statement, Int32($0)).rounded()) }
            guard tokens.allSatisfy({ $0 >= 0 }) else { continue }
            let sessionID = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            samples.append(OpenAIUsageSample(hour: Date(timeIntervalSince1970: timestamp), modelID: String(cString: modelText), inputTokens: tokens[0], cachedInputTokens: tokens[1], cacheWriteTokens: tokens[2], outputTokens: tokens[3], source: source, sessionID: sessionID))
        } while stepResult == SQLITE_ROW
        return (samples, stepResult == SQLITE_DONE)
    }

    private var cutoff: Date {
        let endHour = floor(now.timeIntervalSince1970 / 3_600) * 3_600
        return Date(timeIntervalSince1970: endHour - Double(UsageHistoryFetcher.bucketCount - 1) * 3_600)
    }

    private func readCodex() -> SourceRead {
        var readable = false
        var samples: [OpenAIUsageSample] = []
        var visited = Set<String>()
        for root in codexRoots {
            let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
            guard visited.insert(canonicalRoot.path).inserted else { continue }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: canonicalRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            readable = true
            guard let sessionFiles = codexSessionFiles(canonicalRoot) else { return ([], false) }
            for fileURL in sessionFiles where fileURL.pathExtension == "jsonl" {
                guard visited.insert(fileURL.standardizedFileURL.path).inserted else { continue }
                let file = readCodexFile(fileURL)
                guard file.readable else { return ([], false) }
                samples.append(contentsOf: file.samples)
            }
        }
        return (samples, readable)
    }

    private func readCodexFile(_ url: URL) -> SourceRead {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return ([], false) }
        var previousTotal: [String: Int64]?
        let fallbackSessionID = url.deletingPathExtension().lastPathComponent
        let samples: [OpenAIUsageSample] = text.split(separator: "\n").compactMap { line in
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  object["type"] as? String == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let timestampText = object["timestamp"] as? String,
                  let timestamp = ISO8601DateFormatter().date(from: timestampText),
                  timestamp >= cutoff, timestamp <= now,
                  let info = payload["info"] as? [String: Any],
                  let modelID = info["model"] as? String else { return nil }
            let current = (info["last_token_usage"] as? [String: Any]).map(tokenValues)
            let total = (info["total_token_usage"] as? [String: Any]).map(tokenValues)
            let values: [String: Int64]
            if let current {
                values = current
                previousTotal = total
            } else if let total {
                values = Dictionary(uniqueKeysWithValues: total.map { key, value in
                    (key, max(0, value - (previousTotal?[key] ?? 0)))
                })
                previousTotal = total
            } else {
                return nil
            }
            let sessionID = (object["session_id"] as? String) ?? (payload["session_id"] as? String) ?? fallbackSessionID
            return OpenAIUsageSample(hour: timestamp, modelID: modelID, inputTokens: values["input"] ?? 0, cachedInputTokens: values["cachedInput"] ?? 0, cacheWriteTokens: values["cacheWrite"] ?? 0, outputTokens: values["output"] ?? 0, source: .codex, sessionID: sessionID)
        }
        return (samples, true)
    }

    private func tokenValues(_ values: [String: Any]) -> [String: Int64] {
        func value(_ key: String) -> Int64 {
            guard let number = values[key] as? NSNumber, number.doubleValue.isFinite else { return 0 }
            return max(0, Int64(number.doubleValue.rounded()))
        }
        return [
            "input": value("input_tokens"),
            "cachedInput": value("cached_input_tokens"),
            "cacheWrite": value("cache_write_input_tokens"),
            "output": value("output_tokens")
        ]
    }
}
