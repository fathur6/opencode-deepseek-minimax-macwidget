import Foundation

public struct QuotaSnapshotRow: Equatable, Sendable {
    public let hour: Date
    public let deepseekUSD: Double?
    public let openaiPercent: Double?
    public let source: String

    public init(hour: Date, deepseekUSD: Double?, openaiPercent: Double?, source: String) {
        self.hour = hour
        self.deepseekUSD = deepseekUSD
        self.openaiPercent = openaiPercent
        self.source = source
    }
}
