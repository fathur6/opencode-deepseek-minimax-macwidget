import Testing
import Foundation
@testable import OpencodeWidget
import OpencodeWidgetShared

@MainActor
@Test func usageEntryCreation() {
    let cache = WidgetCache(lastUpdated: Date())
    let entry = UsageEntry(date: Date(), cache: cache)
    #expect(entry.cache.lastUpdated == cache.lastUpdated)
}

@MainActor
@Test func widgetViewConstruction() {
    let row = DailyUsageRow(date: "2026-06-30", deepseekTokens: 100, deepseekCost: 0.5, minimaxTokens: 50, minimaxCost: 0.2)
    let cache = WidgetCache(lastUpdated: Date(), dailyUsage: [row])
    let entry = UsageEntry(date: Date(), cache: cache)
    let view = WidgetView(entry: entry)
    #expect(view.entry.cache.dailyUsage.count == 1)
}

@MainActor
@Test func balanceCardViewConstruction() {
    let view = BalanceCardView(title: "Deepseek", balance: 10.0, color: .blue)
    #expect(view.title == "Deepseek")
}

@MainActor
@Test func balanceCardViewNilBalance() {
    let view = BalanceCardView(title: "MiniMax", balance: nil, color: .green)
    #expect(view.balance == nil)
}

@MainActor
@Test func usageChartViewConstruction() {
    let rows = [
        DailyUsageRow(date: "2026-06-26", deepseekTokens: 100, minimaxTokens: 50),
        DailyUsageRow(date: "2026-06-27", deepseekTokens: 200, minimaxTokens: 75),
        DailyUsageRow(date: "2026-06-28", deepseekTokens: 150, minimaxTokens: 60),
        DailyUsageRow(date: "2026-06-29", deepseekTokens: 300, minimaxTokens: 100),
        DailyUsageRow(date: "2026-06-30", deepseekTokens: 250, minimaxTokens: 90),
    ]
    let view = UsageChartView(dailyUsage: rows)
    #expect(!view.dailyUsage.isEmpty)
}

@MainActor
@Test func costFooterViewConstruction() {
    let rows = [
        DailyUsageRow(date: "2026-06-30", deepseekCost: 1.5, minimaxCost: 0.5),
    ]
    let view = CostFooterView(dailyUsage: rows)
    #expect(view.dailyUsage.count == 1)
}
