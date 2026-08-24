import Foundation
import SQLite3
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

public final class QuotaLedger {
    private var db: OpaquePointer?

    public init(path: String) {
        var handle: OpaquePointer?
        if sqlite3_open(path, &handle) == SQLITE_OK, let handle {
            db = handle
            createSchema()
        } else {
            db = nil
        }
    }

    public static func open(path: String) -> QuotaLedger {
        QuotaLedger(path: path)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    private func createSchema() {
        guard let db else { return }
        let schema = """
        CREATE TABLE IF NOT EXISTS quota_snapshots(
          hour TEXT PRIMARY KEY,
          deepseek_usd REAL,
          openai_percent REAL,
          source TEXT,
          recorded_at TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_quota_snapshots_hour ON quota_snapshots(hour);
        CREATE TABLE IF NOT EXISTS quota_month_mark(
          yyyy_mm TEXT PRIMARY KEY,
          emailed_at TEXT
        );
        """
        sqlite3_exec(db, schema, nil, nil, nil)
    }

    private func flooredHour(_ date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 3_600) * 3_600)
    }

    private func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func isoFromString(_ s: String) -> Date? {
        ISO8601DateFormatter().date(from: s)
    }

    private func sqliteText(_ values: OpaquePointer?, index: Int32) -> String? {
        guard let ptr = sqlite3_column_text(values, index) else { return nil }
        return String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
    }

    private func bindText(_ stmt: OpaquePointer?, index: Int32, _ value: String?) {
        guard let value else {
            sqlite3_bind_null(stmt, index)
            return
        }
        value.withCString { cstr in
            sqlite3_bind_text(stmt, index, cstr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
    }

    public func record(hour: Date, deepseekUSD: Double?, openaiPercent: Double?, source: String) {
        guard let db else { return }
        let h = flooredHour(hour)
        let sql = """
        INSERT INTO quota_snapshots(hour, deepseek_usd, openai_percent, source, recorded_at)
        VALUES(?, ?, ?, ?, ?)
        ON CONFLICT(hour) DO UPDATE SET
          deepseek_usd = excluded.deepseek_usd,
          openai_percent = excluded.openai_percent,
          source = excluded.source,
          recorded_at = excluded.recorded_at
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        bindText(stmt, index: 1, iso(h))
        if let d = deepseekUSD {
            sqlite3_bind_double(stmt, 2, d)
        } else {
            sqlite3_bind_null(stmt, 2)
        }
        if let p = openaiPercent {
            sqlite3_bind_double(stmt, 3, p)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        bindText(stmt, index: 4, source)
        bindText(stmt, index: 5, iso(Date()))
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    public func prune(retentionMonths: Int = 12, now: Date = Date()) {
        guard let db else { return }
        var comp = DateComponents()
        comp.month = -retentionMonths
        guard let cutoff = Calendar.current.date(byAdding: comp, to: now) else { return }
        let startOfCutoffMonth = Calendar.current.dateInterval(of: .month, for: cutoff)?.start ?? cutoff
        let sql = "DELETE FROM quota_snapshots WHERE hour < ?"
        let cutoffStr = iso(startOfCutoffMonth)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        bindText(stmt, index: 1, cutoffStr)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    public func rows(from: Date, to: Date) -> [QuotaSnapshotRow] {
        guard let db else { return [] }
        let sql = "SELECT hour, deepseek_usd, openai_percent, source FROM quota_snapshots WHERE hour >= ? AND hour < ? ORDER BY hour ASC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        bindText(stmt, index: 1, iso(from))
        bindText(stmt, index: 2, iso(to))
        var result: [QuotaSnapshotRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let hstr = sqliteText(stmt, index: 0),
                  let h = isoFromString(hstr) else { continue }
            let d: Double? = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 1)
            let p: Double? = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 2)
            let src = sqliteText(stmt, index: 3) ?? ""
            result.append(QuotaSnapshotRow(hour: h, deepseekUSD: d, openaiPercent: p, source: src))
        }
        sqlite3_finalize(stmt)
        return result
    }

    public func monthRows(month: Date) -> [QuotaSnapshotRow] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: month) else { return [] }
        return rows(from: interval.start, to: interval.end)
    }

    public func count() -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM quota_snapshots", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        var n = 0
        if sqlite3_step(stmt) == SQLITE_ROW { n = Int(sqlite3_column_int64(stmt, 0)) }
        sqlite3_finalize(stmt)
        return n
    }

    public func markMonthEmailed(yyyyMM: String) {
        guard let db else { return }
        let sql = "INSERT INTO quota_month_mark(yyyy_mm, emailed_at) VALUES(?, ?) ON CONFLICT(yyyy_mm) DO UPDATE SET emailed_at = excluded.emailed_at"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        bindText(stmt, index: 1, yyyyMM)
        bindText(stmt, index: 2, iso(Date()))
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    public func isMonthEmailed(yyyyMM: String) -> Bool {
        guard let db else { return false }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM quota_month_mark WHERE yyyy_mm = ?", -1, &stmt, nil) == SQLITE_OK else { return false }
        bindText(stmt, index: 1, yyyyMM)
        let found = sqlite3_step(stmt) == SQLITE_ROW
        sqlite3_finalize(stmt)
        return found
    }

    public func backfill(deepseek: [DeepSeekBalanceSnapshot], openAI: [OpenAIQuotaSnapshot]) {
        guard count() == 0 else { return }
        var dsByHour: [Date: Double] = [:]
        var oaByHour: [Date: Double] = [:]
        for snap in deepseek {
            dsByHour[flooredHour(snap.hour)] = snap.remainingRM / DeepSeekBalanceHistory.usdToMYR
        }
        for snap in openAI {
            oaByHour[flooredHour(snap.hour)] = snap.remainingPercent
        }
        let allHours = Set(dsByHour.keys).union(oaByHour.keys).sorted()
        for hour in allHours {
            let d = dsByHour[hour]
            let p = oaByHour[hour]
            if d == nil && p == nil { continue }
            let source: String
            if d != nil && p != nil {
                source = "both"
            } else if d != nil {
                source = "deepseek"
            } else {
                source = "openai"
            }
            record(hour: hour, deepseekUSD: d, openaiPercent: p, source: source)
        }
    }
}
