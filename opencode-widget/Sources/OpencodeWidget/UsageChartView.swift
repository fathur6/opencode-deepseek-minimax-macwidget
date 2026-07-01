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
            Text("Daily Tokens")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(dailyUsage.suffix(5)) { row in
                    VStack(spacing: 2) {
                        let dsH = maxTokens > 0 ? CGFloat(row.deepseekTokens) / CGFloat(maxTokens) * 60 : 0
                        let mmH = maxTokens > 0 ? CGFloat(row.minimaxTokens) / CGFloat(maxTokens) * 60 : 0

                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.primary.opacity(0.8))
                                .frame(height: max(dsH, 2))
                            Rectangle()
                                .fill(Color.primary.opacity(0.3))
                                .frame(height: max(mmH, 2))
                        }
                        .frame(width: 36)
                        .cornerRadius(2)

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
