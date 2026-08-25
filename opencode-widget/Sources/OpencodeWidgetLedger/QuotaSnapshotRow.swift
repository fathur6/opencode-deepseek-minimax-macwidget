import Foundation

public struct QuotaSnapshotRow: Equatable, Sendable {
    public let hour: Date
    public let deepseekUSD: Double?
    public let openaiPercent: Double?
    public let deepseekInputTokens: Int?
    public let openAIInputTokens: Int?
    public let openAIEstimatedCostUSD: Double?
    public let source: String

    public init(
        hour: Date,
        deepseekUSD: Double?,
        openaiPercent: Double?,
        deepseekInputTokens: Int? = nil,
        openAIInputTokens: Int? = nil,
        openAIEstimatedCostUSD: Double? = nil,
        source: String
    ) {
        self.hour = hour
        self.deepseekUSD = deepseekUSD
        self.openaiPercent = openaiPercent
        self.deepseekInputTokens = deepseekInputTokens
        self.openAIInputTokens = openAIInputTokens
        self.openAIEstimatedCostUSD = openAIEstimatedCostUSD
        self.source = source
    }
}
