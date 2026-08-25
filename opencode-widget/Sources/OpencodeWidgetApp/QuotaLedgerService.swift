import Foundation
#if canImport(OpencodeWidgetLedger)
import OpencodeWidgetLedger
#endif
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct ProcessQuotaEmailSender: QuotaEmailSending {
    let script = "\(NSHomeDirectory())/.hermes/skills/productivity/google-workspace/scripts/google_api.py"

    func sendQuotaReport(subject: String, body: String, to: String) async -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        p.arguments = [script, "gmail", "send", "--to", to, "--subject", subject, "--body", body]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }
}

@MainActor
final class QuotaLedgerService {
    static let shared = QuotaLedgerService()

    let ledger: QuotaLedger
    private let reporter: QuotaMonthlyReporter
    private let to = "fathur6@gmail.com"

    init(ledgerPath: String? = nil) {
        let fm = FileManager.default
        let base = ledgerPath ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OpencodeWidgetApp", isDirectory: true).path
        let dbPath = ledgerPath ?? "\(base)/quota.db"
        let parent = (dbPath as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: parent, withIntermediateDirectories: true)
        let ledger = QuotaLedger.open(path: dbPath)
        let sender = ProcessQuotaEmailSender()
        let archiveDir = "\(base)/archive"
        self.ledger = ledger
        self.reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: to, now: { Date() }, archiveDir: archiveDir)
    }

    func begin(of cache: WidgetCache) {
        ledger.backfill(deepseek: cache.deepseekBalanceHistory, openAI: cache.openAIQuotaHistory)
        ledger.prune(retentionMonths: 12)
    }

    /// Merge the durable ledger's recent snapshots into the cache's in-memory
    /// history so the visible Quota chart reflects persisted data across rebuilds.
    func seededCache(from cache: WidgetCache, limit: Int = 720) -> WidgetCache {
        let rows = ledger.recentSnapshots(limit: limit)
        guard !rows.isEmpty else { return cache }
        let deepseekHistory = rows.compactMap { row -> DeepSeekBalanceSnapshot? in
            guard let usd = row.deepseekUSD else { return nil }
            return DeepSeekBalanceSnapshot(hour: row.hour, remainingRM: usd * DeepSeekBalanceHistory.usdToMYR)
        }
        let openAIHistory = rows.compactMap { row -> OpenAIQuotaSnapshot? in
            guard let percent = row.openaiPercent else { return nil }
            return OpenAIQuotaSnapshot(hour: row.hour, remainingPercent: percent)
        }
        let hourlyUsage = rows.map { row in
            HourlyUsageBucket(
                hour: row.hour,
                openAIInputTokens: Int64(row.openAIInputTokens ?? 0),
                deepseekInputTokens: Int64(row.deepseekInputTokens ?? 0)
            )
        }
        return WidgetCache(
            lastUpdated: cache.lastUpdated,
            deepseek: cache.deepseek,
            minimax: cache.minimax,
            minimaxUsage: cache.minimaxUsage,
            minimaxCredit: cache.minimaxCredit,
            minimaxCreditFetched: cache.minimaxCreditFetched,
            dailyUsage: cache.dailyUsage,
            openAIQuota: cache.openAIQuota,
            hourlyUsage: hourlyUsage,
            deepseekBalanceHistory: deepseekHistory,
            openAIQuotaHistory: openAIHistory
        )
    }

    func recordRefresh(cache: WidgetCache) {
        if ledger.count() == 0 { begin(of: cache) }
        let now = Date()
        let dsUSD = cache.deepseek.balance
        let oaPercent = cache.openAIQuota?.remainingPercent
        let currentHour = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 / 3_600) * 3_600)
        let hourlyTotal = OpenAIUsageCollector().hourlyTotals()?[currentHour]
        guard dsUSD != nil || oaPercent != nil || hourlyTotal != nil else { return }
        ledger.record(
            hour: now,
            deepseekUSD: dsUSD,
            openaiPercent: oaPercent,
            openAIInputTokens: hourlyTotal?.inputTokens,
            openAIEstimatedCostUSD: hourlyTotal?.estimatedCostUSD,
            source: sourceLabel(ds: dsUSD, oa: oaPercent)
        )
        ledger.prune(retentionMonths: 12)
    }

    func runMonthlyReportIfDue() async {
        _ = await reporter.runIfDue()
    }

    private func sourceLabel(ds: Double?, oa: Double?) -> String {
        switch (ds, oa) {
        case (.some, .some): return "both"
        case (.some, nil): return "deepseek"
        case (nil, .some): return "openai"
        case (nil, nil): return ""
        }
    }
}
