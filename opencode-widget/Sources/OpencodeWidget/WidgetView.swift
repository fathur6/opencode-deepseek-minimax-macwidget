import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct WidgetView: View {
    var entry: UsageEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Usage")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(entry.cache.lastUpdated, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                BalanceCardView(
                    title: "DeepSeek",
                    balance: entry.cache.deepseek.balance
                )
                BalanceCardView(
                    title: "MiniMax",
                    balance: entry.cache.minimax.balance
                )
            }

            if !entry.cache.dailyUsage.isEmpty {
                UsageChartView(dailyUsage: entry.cache.dailyUsage)
                CostFooterView(dailyUsage: entry.cache.dailyUsage)
            } else {
                Text("No usage data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
