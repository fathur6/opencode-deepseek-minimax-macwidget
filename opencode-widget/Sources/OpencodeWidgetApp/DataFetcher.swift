import Foundation
import SQLite3
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

enum DataFetcher {
    static let deepseekBalanceURL = URL(string: "https://api.deepseek.com/user/balance")!
    static let minimaxUsageURL = URL(string: "https://api.minimax.io/v1/api/openplatform/coding_plan/remains")!
    static let minimaxCreditURL = URL(string: "https://platform.minimax.io/account/query_balance")!
    static let openAIUsageURL = OpenAIQuotaFetcher.usageURL

    static func fetchMiniMaxCredit(apiKey: String, session: URLSession = .shared) async -> Double? {
        var request = URLRequest(url: minimaxCreditURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        guard let data = try? await session.data(for: request).0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let amountStr = json["available_amount"] as? String,
              let balance = Double(amountStr) else {
            return nil
        }
        return balance
    }

    static func fetchDeepseekBalance(apiKey: String, session: URLSession = .shared) async -> Double? {
        var request = URLRequest(url: deepseekBalanceURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        guard let data = try? await session.data(for: request).0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let infos = json["balance_infos"] as? [[String: Any]],
              let first = infos.first,
              let balanceStr = first["total_balance"] as? String,
              let balance = Double(balanceStr) else {
            return nil
        }
        return balance
    }

    static func fetchMiniMaxUsage(apiKey: String, session: URLSession = .shared) async -> MiniMaxUsage? {
        var request = URLRequest(url: minimaxUsageURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        guard let data = try? await session.data(for: request).0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelRemains = json["modelRemains"] as? [[String: Any]] else {
            return nil
        }

        let totalCount = modelRemains.compactMap { $0["currentIntervalTotalCount"] as? Int }.reduce(0, +)
        let remainingCount = modelRemains.compactMap { $0["currentIntervalRemainingCount"] as? Int }.reduce(0, +)

        return MiniMaxUsage(remainingPrompts: remainingCount, totalPrompts: totalCount)
    }

    static func queryUsageFromDB(dbPath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db") -> [DailyUsageRow] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            sqlite3_close(db)
            return []
        }

        let query = """
        SELECT
          date(time_created, 'unixepoch') as day,
          json_extract(model, '$.providerID') as provider,
          SUM(tokens_input + tokens_output) as total_tokens,
          SUM(cost) as total_cost
        FROM session
        WHERE model IS NOT NULL AND model != ''
          AND time_created > strftime('%s', 'now', '-6 days')
        GROUP BY day, provider
        ORDER BY day
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return []
        }

        var rowsByDate: [String: DailyUsageRow] = [:]

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let dayPtr = sqlite3_column_text(statement, 0),
                  let providerPtr = sqlite3_column_text(statement, 1) else { continue }
            let day = String(cString: dayPtr)
            let provider = String(cString: providerPtr)
            let tokens = Int(sqlite3_column_int64(statement, 2))
            let cost = sqlite3_column_double(statement, 3)

            var row = rowsByDate[day] ?? DailyUsageRow(date: day)
            if provider == "deepseek" {
                row.deepseekTokens += tokens
                row.deepseekCost += cost
            } else if provider == "minimax" {
                row.minimaxTokens += tokens
                row.minimaxCost += cost
            }
            rowsByDate[day] = row
        }

        sqlite3_finalize(statement)
        sqlite3_close(db)

        return rowsByDate.values.sorted { $0.date < $1.date }
    }

    static func readSavedMiniMaxBalance() -> Double? {
        let defaults = UserDefaults(suiteName: "group.com.opencode.widget")
        guard let str = defaults?.string(forKey: "minimaxBalance"),
              !str.isEmpty else { return nil }
        return Double(str.replacingOccurrences(of: "$", with: ""))
    }

    static func readSavedMiniMaxCredit() -> Double? {
        let defaults = UserDefaults(suiteName: "group.com.opencode.widget")
        let val = defaults?.double(forKey: "minimaxCredit") ?? 0
        return val > 0 ? val : nil
    }

    static func refreshAll(
        dbPath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db",
        authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json",
        session: URLSession = .shared,
        openAIAuthPath: String = "\(NSHomeDirectory())/.codex/auth.json",
        cacheSuiteName: String = DataStore.defaultSuiteName,
        cacheFileName: String = DataStore.defaultFileName,
        historyNow: Date = Date(),
        openCodeHistoryDBPath: String? = nil,
        hermesHistoryDBPath: String = "\(NSHomeDirectory())/.hermes/state.db",
        codexHistoryRoots: [URL] = [
            URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/sessions", isDirectory: true),
            URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/archived_sessions", isDirectory: true)
        ],
        historyFetcher: (@Sendable () -> UsageHistoryResult)? = nil,
        openAIQuotaFetcher: @escaping @Sendable (String, URLSession, URL) async -> OpenAIQuota? = { authPath, session, endpoint in
            await OpenAIQuotaFetcher.fetch(authPath: authPath, session: session, endpoint: endpoint)
        }
    ) async -> WidgetCache {
        let usage = queryUsageFromDB(dbPath: dbPath)
        let previousCache = DataStore.load(suiteName: cacheSuiteName, fileName: cacheFileName)
        let previousQuota = previousCache?.openAIQuota
        let resolvedOpenCodeHistoryDBPath = openCodeHistoryDBPath ?? dbPath
        let historyTask = Task.detached {
            if let historyFetcher { return historyFetcher() }
            return UsageHistoryFetcher(
                now: historyNow,
                openCodeDatabasePath: resolvedOpenCodeHistoryDBPath,
                hermesDatabasePath: hermesHistoryDBPath,
                codexRoots: codexHistoryRoots
            ).fetch()
        }
        let fetchedOpenAIQuotaTask = Task {
            await openAIQuotaFetcher(openAIAuthPath, session, openAIUsageURL)
        }

        guard let creds = AuthReader.readCredentials(authPath: authPath) else {
            let miniCredit = readSavedMiniMaxCredit()
            let openAIQuota = await fetchedOpenAIQuotaTask.value ?? previousQuota
            let history = await historyTask.value
            return WidgetCache(
                lastUpdated: Date(),
                deepseek: ProviderBalance(balance: nil, currency: "USD"),
                minimax: ProviderBalance(balance: miniCredit ?? readSavedMiniMaxBalance(), currency: "USD"),
                minimaxCredit: miniCredit,
                minimaxCreditFetched: miniCredit != nil ? Date() : nil,
                dailyUsage: usage,
                openAIQuota: openAIQuota,
                hourlyUsage: history.anySourceReadable ? history.buckets : previousCache?.hourlyUsage ?? [],
                deepseekBalanceHistory: previousCache?.deepseekBalanceHistory ?? []
            )
        }

        let dk = creds.deepseekKey
        let mk = creds.minimaxKey
        async let dsBalance = fetchDeepseekBalance(apiKey: dk, session: session)
        async let mmCredit = fetchMiniMaxCredit(apiKey: mk, session: session)
        async let mmUsage = fetchMiniMaxUsage(apiKey: mk, session: session)

        let (deepseekBalance, minimaxCredit, minimaxUsage) = await (dsBalance, mmCredit, mmUsage)
        let deepseekBalanceHistory = DeepSeekBalanceHistory.appending(
            balanceUSD: deepseekBalance,
            at: historyNow,
            to: previousCache?.deepseekBalanceHistory ?? []
        )
        let openAIQuota = await fetchedOpenAIQuotaTask.value
        let history = await historyTask.value

        let minimaxCreditVal: Double?
        if let credit = minimaxCredit {
            minimaxCreditVal = credit
        } else {
            minimaxCreditVal = readSavedMiniMaxCredit()
        }

        let minimaxBalance = minimaxCreditVal ?? minimaxUsage.map { Double($0.remainingPrompts) } ?? readSavedMiniMaxBalance()

        return WidgetCache(
            lastUpdated: Date(),
            deepseek: ProviderBalance(balance: deepseekBalance, currency: "USD"),
            minimax: ProviderBalance(balance: minimaxBalance, currency: "USD"),
            minimaxUsage: minimaxUsage,
            minimaxCredit: minimaxCreditVal,
            minimaxCreditFetched: minimaxCredit != nil ? Date() : nil,
            dailyUsage: usage,
            openAIQuota: openAIQuota ?? previousQuota,
            hourlyUsage: history.anySourceReadable ? history.buckets : previousCache?.hourlyUsage ?? [],
            deepseekBalanceHistory: deepseekBalanceHistory
        )
    }
}
