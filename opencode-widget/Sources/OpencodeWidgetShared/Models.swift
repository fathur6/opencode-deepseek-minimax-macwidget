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

public struct MiniMaxUsage: Codable, Equatable {
    public var remainingPrompts: Int
    public var totalPrompts: Int

    public init(remainingPrompts: Int = 0, totalPrompts: Int = 0) {
        self.remainingPrompts = remainingPrompts
        self.totalPrompts = totalPrompts
    }

    public var percentage: Double {
        totalPrompts > 0 ? Double(remainingPrompts) / Double(totalPrompts) : 0
    }
}

public struct MiniMaxModelRemain: Codable, Identifiable, Equatable {
    public var id: String { modelName }
    public let modelName: String
    public let currentIntervalTotalCount: Int
    public let currentIntervalRemainingCount: Int
    public let startTime: Int64
    public let endTime: Int64
    public let remainsTime: Int64

    public init(modelName: String, currentIntervalTotalCount: Int, currentIntervalRemainingCount: Int, startTime: Int64, endTime: Int64, remainsTime: Int64) {
        self.modelName = modelName
        self.currentIntervalTotalCount = currentIntervalTotalCount
        self.currentIntervalRemainingCount = currentIntervalRemainingCount
        self.startTime = startTime
        self.endTime = endTime
        self.remainsTime = remainsTime
    }

    public var usagePercentage: Double {
        guard currentIntervalTotalCount > 0 else { return 0 }
        return Double(currentIntervalTotalCount - currentIntervalRemainingCount) / Double(currentIntervalTotalCount)
    }
}

public struct MiniMaxCodingPlanResponse: Codable {
    public let modelRemains: [MiniMaxModelRemain]
    public let baseResp: MiniMaxBaseResp?

    public init(modelRemains: [MiniMaxModelRemain], baseResp: MiniMaxBaseResp?) {
        self.modelRemains = modelRemains
        self.baseResp = baseResp
    }
}

public struct MiniMaxBaseResp: Codable {
    public let statusCode: Int
    public let statusMsg: String?
}

public struct ModelUsageRow: Codable, Identifiable, Equatable {
    public var id: String { "\(date)-\(provider)-\(modelId)" }
    public let date: String
    public let provider: String
    public let modelId: String
    public let tokens: Int
    public let cost: Double

    public init(date: String, provider: String, modelId: String, tokens: Int, cost: Double) {
        self.date = date
        self.provider = provider
        self.modelId = modelId
        self.tokens = tokens
        self.cost = cost
    }
}

public struct WidgetCache: Codable {
    public let lastUpdated: Date
    public var deepseek: ProviderBalance
    public var minimax: ProviderBalance
    public var minimaxUsage: MiniMaxUsage?
    public var minimaxCredit: Double?
    public var minimaxCreditFetched: Date?
    public var dailyUsage: [DailyUsageRow]

    public init(lastUpdated: Date = Date(), deepseek: ProviderBalance = ProviderBalance(), minimax: ProviderBalance = ProviderBalance(), minimaxUsage: MiniMaxUsage? = nil, minimaxCredit: Double? = nil, minimaxCreditFetched: Date? = nil, dailyUsage: [DailyUsageRow] = []) {
        self.lastUpdated = lastUpdated
        self.deepseek = deepseek
        self.minimax = minimax
        self.minimaxUsage = minimaxUsage
        self.minimaxCredit = minimaxCredit
        self.minimaxCreditFetched = minimaxCreditFetched
        self.dailyUsage = dailyUsage
    }

    public var isEmpty: Bool {
        dailyUsage.isEmpty && deepseek.balance == nil && minimax.balance == nil
    }
}
