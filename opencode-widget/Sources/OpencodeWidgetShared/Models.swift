import Foundation

public struct ProviderBalance: Codable, Equatable {
    public var balance: Double?
    public var currency: String

    public init(balance: Double? = nil, currency: String = "USD") {
        self.balance = balance
        self.currency = currency
    }
}

public struct DailyUsageRow: Codable, Identifiable, Equatable {
    public var id: String { date }
    public let date: String
    public var deepseekTokens: Int
    public var deepseekCost: Double
    public var minimaxTokens: Int
    public var minimaxCost: Double

    public init(date: String, deepseekTokens: Int = 0, deepseekCost: Double = 0, minimaxTokens: Int = 0, minimaxCost: Double = 0) {
        self.date = date
        self.deepseekTokens = deepseekTokens
        self.deepseekCost = deepseekCost
        self.minimaxTokens = minimaxTokens
        self.minimaxCost = minimaxCost
    }

    public var totalTokens: Int { deepseekTokens + minimaxTokens }
    public var totalCost: Double { deepseekCost + minimaxCost }
}

public struct WidgetCache: Codable {
    public let lastUpdated: Date
    public var deepseek: ProviderBalance
    public var minimax: ProviderBalance
    public var dailyUsage: [DailyUsageRow]

    public init(lastUpdated: Date = Date(), deepseek: ProviderBalance = ProviderBalance(), minimax: ProviderBalance = ProviderBalance(), dailyUsage: [DailyUsageRow] = []) {
        self.lastUpdated = lastUpdated
        self.deepseek = deepseek
        self.minimax = minimax
        self.dailyUsage = dailyUsage
    }

    public var isEmpty: Bool {
        dailyUsage.isEmpty && deepseek.balance == nil && minimax.balance == nil
    }
}
