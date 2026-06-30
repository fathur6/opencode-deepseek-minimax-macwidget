import Foundation
import SQLite3
import OpencodeWidgetShared

enum DataFetcher {
    static let deepseekBalanceURL = URL(string: "https://api.deepseek.com/user/balance")!

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
            let day = String(cString: sqlite3_column_text(statement, 0))
            let provider = String(cString: sqlite3_column_text(statement, 1))
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

    static func refreshAll(dbPath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db", authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json", session: URLSession = .shared) async -> WidgetCache {
        guard let creds = AuthReader.readCredentials(authPath: authPath) else {
            return WidgetCache(
                lastUpdated: Date(),
                deepseek: ProviderBalance(balance: nil, currency: "USD"),
                minimax: ProviderBalance(balance: nil, currency: "USD"),
                dailyUsage: queryUsageFromDB(dbPath: dbPath)
            )
        }

        let deepseekBalance = await fetchDeepseekBalance(apiKey: creds.deepseekKey, session: session)
        let usage = queryUsageFromDB(dbPath: dbPath)

        return WidgetCache(
            lastUpdated: Date(),
            deepseek: ProviderBalance(balance: deepseekBalance, currency: "USD"),
            minimax: ProviderBalance(balance: nil, currency: "USD"),
            dailyUsage: usage
        )
    }
}
