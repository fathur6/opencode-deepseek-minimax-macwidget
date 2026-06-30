import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct TimelineChart: View {
    let dailyUsage: [DailyUsageRow]

    private var maxTokens: Int {
        dailyUsage.map(\.totalTokens).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Daily Token Usage")
                .font(.system(size: DesignSystem.Typography.caption))
                .foregroundColor(.secondary)

            HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
                ForEach(dailyUsage.suffix(7)) { row in
                    VStack(spacing: 2) {
                        let deepHeight: CGFloat = maxTokens > 0 ? CGFloat(row.deepseekTokens) / CGFloat(maxTokens) * 80 : 0
                        let miniHeight: CGFloat = maxTokens > 0 ? CGFloat(row.minimaxTokens) / CGFloat(maxTokens) * 80 : 0

                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(DesignSystem.Color.deepseekAccent.opacity(0.7))
                                .frame(height: max(deepHeight, 2))
                            Rectangle()
                                .fill(DesignSystem.Color.minimaxAccent.opacity(0.7))
                                .frame(height: max(miniHeight, 2))
                        }
                        .frame(width: 32)
                        .cornerRadius(DesignSystem.Radius.sm)

                        Text(formatDate(row.date))
                            .font(.system(size: DesignSystem.Typography.captionSmall))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 90)

            HStack(spacing: DesignSystem.Spacing.md) {
                Label("DeepSeek", systemImage: "circle.fill")
                    .font(.system(size: DesignSystem.Typography.captionSmall))
                    .foregroundColor(DesignSystem.Color.deepseekAccent)
                Label("MiniMax", systemImage: "circle.fill")
                    .font(.system(size: DesignSystem.Typography.captionSmall))
                    .foregroundColor(DesignSystem.Color.minimaxAccent)
            }
        }
    }

    private func formatDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count >= 3 else { return date }
        return "\(parts[1])/\(parts[2])"
    }
}
