import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct CostFooterView: View {
    let dailyUsage: [DailyUsageRow]

    private var todayCost: Double { dailyUsage.last?.totalCost ?? 0 }
    private var weekCost: Double { dailyUsage.reduce(0) { $0 + $1.totalCost } }

    var body: some View {
        HStack {
            Label(String(format: "Today: $%.2f", todayCost), systemImage: "arrow.up.circle")
            Spacer()
            Label(String(format: "7-day: $%.2f", weekCost), systemImage: "clock")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}
