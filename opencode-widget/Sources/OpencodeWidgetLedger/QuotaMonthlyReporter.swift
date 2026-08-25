import Foundation

public protocol QuotaEmailSending: Sendable {
    func sendQuotaReport(subject: String, body: String, to: String) async -> Bool
}

public struct QuotaMonthlySummary: Equatable {
    public let daysWithData: Int
    public let daysWithGap: Int
    public let topUpCount: Int
    public let avgDeepseekUSD: Double?
    public let avgOpenaiPercent: Double?

    public init(daysWithData: Int, daysWithGap: Int, topUpCount: Int, avgDeepseekUSD: Double?, avgOpenaiPercent: Double?) {
        self.daysWithData = daysWithData
        self.daysWithGap = daysWithGap
        self.topUpCount = topUpCount
        self.avgDeepseekUSD = avgDeepseekUSD
        self.avgOpenaiPercent = avgOpenaiPercent
    }
}

public enum QuotaReportFormatter {
    public static func isLastCalendarDay(of date: Date, calendar: Calendar = .current) -> Bool {
        guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { return false }
        return !calendar.isDate(date, equalTo: next, toGranularity: .month)
    }

    public static func yyyyMM(_ month: Date, calendar: Calendar = .current) -> String {
        let comp = calendar.dateComponents([.year, .month], from: month)
        return String(format: "%04d-%02d", comp.year ?? 0, comp.month ?? 0)
    }

    public static func monthTitle(_ month: Date) -> String {
        month.formatted(.dateTime.month(.wide).year())
    }

    public static func csv(rows: [QuotaSnapshotRow]) -> String {
        var out = "hour,deepseek_usd,openai_percent,source\n"
        let iso = ISO8601DateFormatter()
        for r in rows {
            let d = r.deepseekUSD.map { String($0) } ?? ""
            let p = r.openaiPercent.map { String($0) } ?? ""
            out += "\(iso.string(from: r.hour)),\(d),\(p),\(r.source)\n"
        }
        return out
    }

    public static func summary(from rows: [QuotaSnapshotRow]) -> QuotaMonthlySummary {
        let dsValues = rows.compactMap(\.deepseekUSD)
        let oaValues = rows.compactMap(\.openaiPercent)
        let days = Set(rows.map { Calendar.current.startOfDay(for: $0.hour) })
        var topUps = 0
        let ordered = rows.sorted { $0.hour < $1.hour }
        var previousUSD: Double?
        for r in ordered {
            if let d = r.deepseekUSD, let p = previousUSD, d > p { topUps += 1 }
            if r.deepseekUSD != nil { previousUSD = r.deepseekUSD }
        }
        let daysWithData = days.count
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: rows.first?.hour ?? Date())?.count ?? 30
        return QuotaMonthlySummary(
            daysWithData: daysWithData,
            daysWithGap: max(0, daysInMonth - daysWithData),
            topUpCount: topUps,
            avgDeepseekUSD: dsValues.isEmpty ? nil : dsValues.reduce(0, +) / Double(dsValues.count),
            avgOpenaiPercent: oaValues.isEmpty ? nil : oaValues.reduce(0, +) / Double(oaValues.count)
        )
    }

    public static func summaryText(summary: QuotaMonthlySummary) -> String {
        let ds = summary.avgDeepseekUSD.map { String(format: "$%.2f", $0) } ?? "n/a"
        let oa = summary.avgOpenaiPercent.map { String(format: "%.1f%%", $0) } ?? "n/a"
        return """
        Days with data: \(summary.daysWithData)
        Days with gaps: \(summary.daysWithGap)
        Top-ups: \(summary.topUpCount)
        Avg DeepSeek balance: \(ds)
        Avg OpenAI remaining: \(oa)
        """
    }

    public static func emailBody(summary: QuotaMonthlySummary, rows: [QuotaSnapshotRow]) -> String {
        "Monthly quota report\n\n" + summaryText(summary: summary) + "\n\n---\n" + csv(rows: rows)
    }
}

public final class QuotaMonthlyReporter: @unchecked Sendable {
    private let ledger: QuotaLedger
    private let sender: QuotaEmailSending
    private let to: String
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let archiveDir: String?

    public init(ledger: QuotaLedger, sender: QuotaEmailSending, to: String, now: @escaping @Sendable () -> Date, calendar: Calendar = .current, archiveDir: String? = nil) {
        self.ledger = ledger
        self.sender = sender
        self.to = to
        self.now = now
        self.calendar = calendar
        self.archiveDir = archiveDir
    }

    @discardableResult
    public func runIfDue() async -> Bool {
        let today = now()
        guard QuotaReportFormatter.isLastCalendarDay(of: today, calendar: calendar) else { return false }
        let yyyyMM = QuotaReportFormatter.yyyyMM(today, calendar: calendar)
        guard !ledger.isMonthEmailed(yyyyMM: yyyyMM) else { return false }
        let rows = ledger.monthRows(month: today)
        guard !rows.isEmpty else { return false }
        let summary = QuotaReportFormatter.summary(from: rows)
        let csv = QuotaReportFormatter.csv(rows: rows)
        let subject = "OpenCode widget quota report — \(QuotaReportFormatter.monthTitle(today))"
        let body = QuotaReportFormatter.emailBody(summary: summary, rows: rows)
        let ok = await sender.sendQuotaReport(subject: subject, body: body, to: to)
        if ok {
            ledger.markMonthEmailed(yyyyMM: yyyyMM)
            if let archiveDir {
                let dir = URL(fileURLWithPath: archiveDir, isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let file = dir.appendingPathComponent("quota-\(yyyyMM).csv")
                try? csv.data(using: .utf8)?.write(to: file, options: .atomic)
            }
        }
        return ok
    }
}
