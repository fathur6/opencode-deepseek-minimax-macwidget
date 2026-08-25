import XCTest
@testable import OpencodeWidgetApp

final class OpenAIUsageCollectorTests: XCTestCase {
    func testHourlyTotalPricesSupportedModelsAndExcludesUnknownModels() {
        let hour = Date(timeIntervalSince1970: 0)
        let samples = [
            OpenAIUsageSample(hour: hour, modelID: "gpt-5.6-terra", inputTokens: 1_000_000, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .openCode, sessionID: "a"),
            OpenAIUsageSample(hour: hour, modelID: "unknown", inputTokens: 1_000_000, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .codex, sessionID: "b")
        ]

        XCTAssertEqual(OpenAIUsageCollector.aggregate(samples)[hour]?.inputTokens, 1_000_000)
        XCTAssertEqual(OpenAIUsageCollector.aggregate(samples)[hour]?.estimatedCostUSD, 2)
    }

    func testDirectCodexSampleWinsOverMirroredHermesSession() {
        let hour = Date(timeIntervalSince1970: 0)
        let codex = OpenAIUsageSample(hour: hour, modelID: "gpt-5.6-luna", inputTokens: 100, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .codex, sessionID: "shared")
        let hermes = OpenAIUsageSample(hour: hour, modelID: "gpt-5.6-luna", inputTokens: 100, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .hermes, sessionID: "shared")

        XCTAssertEqual(OpenAIUsageCollector.aggregate([codex, hermes])[hour]?.inputTokens, 100)
    }

    func testDirectOpenCodeSampleWinsOverMirroredHermesSession() {
        let hour = Date(timeIntervalSince1970: 0)
        let openCode = OpenAIUsageSample(hour: hour, modelID: "gpt-5.6-luna", inputTokens: 100, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .openCode, sessionID: "shared")
        let hermes = OpenAIUsageSample(hour: hour, modelID: "gpt-5.6-luna", inputTokens: 100, cachedInputTokens: 0, cacheWriteTokens: 0, outputTokens: 0, source: .hermes, sessionID: "shared")

        XCTAssertEqual(OpenAIUsageCollector.aggregate([openCode, hermes])[hour]?.inputTokens, 100)
    }
}
