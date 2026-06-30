import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct ModelCard: View {
    let modelName: String
    let provider: String
    let totalPrompts: Int?
    let remainingPrompts: Int?
    let tokens: Int
    let cost: Double

    private var usagePercentage: Double {
        guard let total = totalPrompts, total > 0 else { return 0 }
        return Double(total - (remainingPrompts ?? 0)) / Double(total)
    }

    private var statusColor: Color {
        switch UsageStatus(usedPercentage: usagePercentage) {
        case .safe: return DesignSystem.Color.safe
        case .warning: return DesignSystem.Color.warning
        case .critical: return DesignSystem.Color.critical
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                StatusIndicator(status: UsageStatus(usedPercentage: usagePercentage))
                Text(modelName)
                    .font(.system(size: DesignSystem.Typography.bodyMedium))
                    .fontWeight(.medium)
                Spacer()
                Text(provider)
                    .font(.system(size: DesignSystem.Typography.caption))
                    .foregroundColor(.secondary)
            }

            if let total = totalPrompts, let remaining = remainingPrompts {
                ProgressBar(value: usagePercentage)
                HStack {
                    Text("\(remaining) / \(total) prompts remaining")
                        .font(.system(size: DesignSystem.Typography.captionSmall))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(UsageStatus(usedPercentage: usagePercentage).label)
                        .font(.system(size: DesignSystem.Typography.captionSmall))
                        .foregroundColor(statusColor)
                }
            }

            if tokens > 0 || cost > 0 {
                HStack {
                    Text("Tokens: \(tokens)")
                        .font(.system(size: DesignSystem.Typography.captionSmall))
                    Spacer()
                    Text(String(format: "Cost: $%.2f", cost))
                        .font(.system(size: DesignSystem.Typography.captionSmall))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}
