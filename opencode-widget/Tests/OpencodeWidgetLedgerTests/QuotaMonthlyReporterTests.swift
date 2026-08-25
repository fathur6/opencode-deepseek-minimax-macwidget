import XCTest
@testable import OpencodeWidgetLedger

final class QuotaMonthlyReporterTests: XCTestCase {
    private var ledger: QuotaLedger!
    private var dbPath: String!

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mrep-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dbPath = dir.appendingPathComponent("quota.db").path
        ledger = QuotaLedger.open(path: dbPath)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: dbPath)
        ledger = nil
        super.tearDown()
    }

    final class FakeSender: QuotaEmailSending, @unchecked Sendable {
        var calls: [(subject: String, body: String, to: String)] = []
        var result = true
        func sendQuotaReport(subject: String, body: String, to: String) async -> Bool {
            calls.append((subject, body, to))
            return result
        }
    }

    func testNotLastDayDoesNothing() async {
        let notLast = isoDate(2026, 8, 15)
        let sender = FakeSender()
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { notLast })
        let sent = await reporter.runIfDue()
        XCTAssertFalse(sent)
        XCTAssertEqual(sender.calls.count, 0)
    }

    func testLastDaySendsSummaryAndCSV() async {
        let last = isoDate(2026, 8, 31)
        let aug1 = isoDate(2026, 8, 1)
        ledger.record(hour: aug1, deepseekUSD: 10, openaiPercent: 50, source: "both")
        let sender = FakeSender()
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { last })
        let sent = await reporter.runIfDue()
        XCTAssertTrue(sent)
        XCTAssertEqual(sender.calls.count, 1)
        XCTAssertEqual(sender.calls[0].to, "fathur6@gmail.com")
        XCTAssertTrue(sender.calls[0].subject.contains("2026"))
        XCTAssertTrue(sender.calls[0].body.contains("hour,deepseek_usd,openai_percent,source"))
        XCTAssertTrue(sender.calls[0].body.contains("10"))
        XCTAssertTrue(ledger.isMonthEmailed(yyyyMM: "2026-08"))
    }

    func testLastDayIdempotent() async {
        let last = isoDate(2026, 8, 31)
        let aug1 = isoDate(2026, 8, 1)
        ledger.record(hour: aug1, deepseekUSD: 10, openaiPercent: 50, source: "both")
        let sender = FakeSender()
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { last })
        _ = await reporter.runIfDue()
        let second = await reporter.runIfDue()
        XCTAssertFalse(second)
        XCTAssertEqual(sender.calls.count, 1)
    }

    func testEmptyMonthDoesNothing() async {
        let last = isoDate(2026, 8, 31)
        let sender = FakeSender()
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { last })
        let sent = await reporter.runIfDue()
        XCTAssertFalse(sent)
        XCTAssertEqual(sender.calls.count, 0)
        XCTAssertFalse(ledger.isMonthEmailed(yyyyMM: "2026-08"))
    }

    func testSendFailureDoesNotArchiveOrMark() async {
        let last = isoDate(2026, 8, 31)
        let aug1 = isoDate(2026, 8, 1)
        ledger.record(hour: aug1, deepseekUSD: 10, openaiPercent: 50, source: "both")
        let sender = FakeSender()
        sender.result = false
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { last })
        let sent = await reporter.runIfDue()
        XCTAssertFalse(sent)
        XCTAssertFalse(ledger.isMonthEmailed(yyyyMM: "2026-08"))
    }

    func testWritesArchiveWhenDirProvided() async {
        let last = isoDate(2026, 8, 31)
        let aug1 = isoDate(2026, 8, 1)
        ledger.record(hour: aug1, deepseekUSD: 10, openaiPercent: 50, source: "both")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("archive-\(UUID().uuidString)").path
        let sender = FakeSender()
        let reporter = QuotaMonthlyReporter(ledger: ledger, sender: sender, to: "fathur6@gmail.com", now: { last }, archiveDir: dir)
        let sent = await reporter.runIfDue()
        XCTAssertTrue(sent)
        let file = URL(fileURLWithPath: dir).appendingPathComponent("quota-2026-08.csv")
        let exists = FileManager.default.fileExists(atPath: file.path)
        XCTAssertTrue(exists)
        let content = try? String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(content?.contains("hour,deepseek_usd,openai_percent,source") ?? false)
    }

    private func isoDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comp = DateComponents()
        comp.year = y; comp.month = m; comp.day = d; comp.hour = 12
        return Calendar.current.date(from: comp)!
    }
}
