import Foundation
import SQLite3
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

enum DataFetcher {
    static let deepseekBalanceURL = URL(string: "https://api.deepseek.com/user/balance")!
    static let minimaxUsageURL = URL(string: "https://api.minimax.io/v1/api/openplatform/coding_plan/remains")!

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

    static func refreshAll(dbPath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db", authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json", session: URLSession = .shared) async -> WidgetCache {
        let usage = queryUsageFromDB(dbPath: dbPath)

        guard let creds = AuthReader.readCredentials(authPath: authPath) else {
            return WidgetCache(
                lastUpdated: Date(),
                deepseek: ProviderBalance(balance: nil, currency: "USD"),
                minimax: ProviderBalance(balance: readSavedMiniMaxBalance(), currency: "USD"),
                dailyUsage: usage
            )
        }

        async let dsBalance = fetchDeepseekBalance(apiKey: creds.deepseekKey, session: session)
        async let mmUsage = fetchMiniMaxUsage(apiKey: creds.minimaxKey, session: session)

        let (deepseekBalance, minimaxUsage) = await (dsBalance, mmUsage)

        return WidgetCache(
            lastUpdated: Date(),
            deepseek: ProviderBalance(balance: deepseekBalance, currency: "USD"),
            minimax: ProviderBalance(
                balance: minimaxUsage.map { Double($0.remainingPrompts) } ?? readSavedMiniMaxBalance(),
                currency: "USD"
            ),
            minimaxUsage: minimaxUsage,
            dailyUsage: usage
        )
    }
}
