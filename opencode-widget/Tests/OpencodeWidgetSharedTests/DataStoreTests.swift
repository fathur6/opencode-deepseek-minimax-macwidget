import XCTest
@testable import OpencodeWidgetShared

final class DataStoreTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: false)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    func tempSuiteName() -> String { tempDir.appendingPathComponent("suite").path }
    func tempFileName() -> String { "test-widget-data.json" }

    // MARK: - Save and Load round-trip

    func testSaveAndLoadRoundTrip() throws {
        let cache = WidgetCache(
            lastUpdated: Date(timeIntervalSince1970: 1719763200),
            deepseek: ProviderBalance(balance: 100.50, currency: "USD"),
            minimax: ProviderBalance(balance: 25.0, currency: "USD"),
            dailyUsage: [
                DailyUsageRow(date: "2026-06-30", deepseekTokens: 100, deepseekCost: 1.5, minimaxTokens: 200, minimaxCost: 3.0)
            ]
        )

        DataStore.save(cache: cache, suiteName: tempSuiteName(), fileName: tempFileName())
        let loaded = DataStore.load(suiteName: tempSuiteName(), fileName: tempFileName())

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.deepseek.balance, 100.50)
        XCTAssertEqual(loaded?.minimax.balance, 25.0)
        XCTAssertEqual(loaded?.dailyUsage.count, 1)
        XCTAssertEqual(loaded?.dailyUsage[0].date, "2026-06-30")
    }

    func testLoadReturnsNilWhenNoFileExists() {
        let loaded = DataStore.load(suiteName: tempSuiteName(), fileName: "nonexistent.json")
        XCTAssertNil(loaded)
    }

    func testRoundTripPreservesISO8601Date() throws {
        let date = Date(timeIntervalSince1970: 1719763200)
        let cache = WidgetCache(lastUpdated: date)

        DataStore.save(cache: cache, suiteName: tempSuiteName(), fileName: tempFileName())
        let loaded = DataStore.load(suiteName: tempSuiteName(), fileName: tempFileName())

        XCTAssertNotNil(loaded)
        let interval = loaded?.lastUpdated.timeIntervalSince1970 ?? 0
        XCTAssertEqual(interval, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testRoundTripWithEmptyCache() throws {
        let cache = WidgetCache()

        DataStore.save(cache: cache, suiteName: tempSuiteName(), fileName: tempFileName())
        let loaded = DataStore.load(suiteName: tempSuiteName(), fileName: tempFileName())

        XCTAssertNotNil(loaded)
        XCTAssertNil(loaded?.deepseek.balance)
        XCTAssertNil(loaded?.minimax.balance)
        XCTAssertTrue(loaded?.dailyUsage.isEmpty ?? false)
    }

    func testLoadReturnsNilForCorruptJSON() throws {
        let fileURL = tempDir.appendingPathComponent(tempFileName())
        try "not-valid-json".write(to: fileURL, atomically: true, encoding: .utf8)

        let loaded = DataStore.load(suiteName: tempSuiteName(), fileName: tempFileName())
        XCTAssertNil(loaded)
    }

    func testOverwriteExistingFile() throws {
        let original = WidgetCache(
            deepseek: ProviderBalance(balance: 100.0)
        )
        DataStore.save(cache: original, suiteName: tempSuiteName(), fileName: tempFileName())

        let updated = WidgetCache(
            deepseek: ProviderBalance(balance: 200.0)
        )
        DataStore.save(cache: updated, suiteName: tempSuiteName(), fileName: tempFileName())

        let loaded = DataStore.load(suiteName: tempSuiteName(), fileName: tempFileName())
        XCTAssertEqual(loaded?.deepseek.balance, 200.0)
    }

    func testConcurrentSaveAndLoad() async {
        let suiteName = tempSuiteName()
        let fileName = tempFileName()
        let iterations = 20

        await withTaskGroup(of: Void.self) { group in
            for id in 0..<iterations {
                group.addTask {
                    let cache = WidgetCache(
                        deepseek: ProviderBalance(balance: Double(id))
                    )
                    DataStore.save(cache: cache, suiteName: suiteName, fileName: fileName)
                    let loaded = DataStore.load(suiteName: suiteName, fileName: fileName)
                    XCTAssertNotNil(loaded)
                }
            }
        }
    }

    func testDifferentSuiteNamesAreIsolated() throws {
        let suiteA = tempDir.appendingPathComponent("suiteA").path
        let suiteB = tempDir.appendingPathComponent("suiteB").path

        let cacheA = WidgetCache(deepseek: ProviderBalance(balance: 10.0))
        let cacheB = WidgetCache(deepseek: ProviderBalance(balance: 20.0))

        DataStore.save(cache: cacheA, suiteName: suiteA, fileName: tempFileName())
        DataStore.save(cache: cacheB, suiteName: suiteB, fileName: tempFileName())

        let loadedA = DataStore.load(suiteName: suiteA, fileName: tempFileName())
        let loadedB = DataStore.load(suiteName: suiteB, fileName: tempFileName())

        XCTAssertEqual(loadedA?.deepseek.balance, 10.0)
        XCTAssertEqual(loadedB?.deepseek.balance, 20.0)
    }
}
