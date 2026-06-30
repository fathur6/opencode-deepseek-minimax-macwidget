import Foundation
import SQLite3
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

public enum DatabaseService {
    public static func queryUsage(dbPath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db") -> [DailyUsageRow] {
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
          AND time_created > strftime('%s', 'now', '-30 days')
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

    public static func queryPerModelUsage(dbPath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db") -> [ModelUsageRow] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            sqlite3_close(db)
            return []
        }

        let query = """
        SELECT
          date(time_created, 'unixepoch') as day,
          json_extract(model, '$.providerID') as provider,
          json_extract(model, '$.id') as model_id,
          SUM(tokens_input + tokens_output) as total_tokens,
          SUM(cost) as total_cost
        FROM session
        WHERE model IS NOT NULL AND model != ''
          AND time_created > strftime('%s', 'now', '-30 days')
        GROUP BY day, provider, model_id
        ORDER BY day
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return []
        }

        var rows: [ModelUsageRow] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let dayPtr = sqlite3_column_text(statement, 0),
                  let providerPtr = sqlite3_column_text(statement, 1),
                  let modelIdPtr = sqlite3_column_text(statement, 2) else { continue }
            let day = String(cString: dayPtr)
            let provider = String(cString: providerPtr)
            let modelId = String(cString: modelIdPtr)
            let tokens = Int(sqlite3_column_int64(statement, 3))
            let cost = sqlite3_column_double(statement, 4)

            rows.append(ModelUsageRow(date: day, provider: provider, modelId: modelId, tokens: tokens, cost: cost))
        }

        sqlite3_finalize(statement)
        sqlite3_close(db)

        return rows
    }
}
