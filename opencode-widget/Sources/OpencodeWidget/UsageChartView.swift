import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct UsageChartView: View {
    let dailyUsage: [DailyUsageRow]

    private var maxTokens: Int {
        dailyUsage.map(\.totalTokens).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daily Token Usage (5 days)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(dailyUsage.suffix(5)) { row in
                    VStack(spacing: 2) {
                        let deepHeight = maxTokens > 0 ? CGFloat(row.deepseekTokens) / CGFloat(maxTokens) * 60 : 0
                        let miniHeight = maxTokens > 0 ? CGFloat(row.minimaxTokens) / CGFloat(maxTokens) * 60 : 0

                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.green.opacity(0.7))
                                .frame(height: max(miniHeight, 2))
                            Rectangle()
                                .fill(Color.blue.opacity(0.7))
                                .frame(height: max(deepHeight, 2))
                        }
                        .frame(width: 36)
                        .cornerRadius(3)

                        Text(formatDate(row.date))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 70)
        }
    }

    private func formatDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count >= 3 else { return date }
        return "\(parts[1])/\(parts[2])"
    }
}
