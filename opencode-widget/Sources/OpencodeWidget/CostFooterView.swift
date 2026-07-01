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
            Text(String(format: "Today: $%.2f", todayCost))
            Spacer()
            Text(String(format: "5d: $%.2f", weekCost))
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}
