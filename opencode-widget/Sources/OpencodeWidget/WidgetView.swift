import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct WidgetView: View {
    var entry: UsageEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.accentColor)
                Text("AI Platform Usage")
                    .font(.headline)
                Spacer()
                Text(entry.cache.lastUpdated, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                BalanceCardView(
                    title: "Deepseek",
                    balance: entry.cache.deepseek.balance,
                    color: .blue
                )
                BalanceCardView(
                    title: "MiniMax",
                    balance: entry.cache.minimax.balance,
                    color: .green
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
