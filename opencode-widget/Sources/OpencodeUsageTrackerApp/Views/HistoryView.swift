import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

enum TimeRange: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case all = "All"

    var dayLimit: Int {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .all: return 365
        }
    }
}

struct HistoryView: View {
    let viewModel: UsageViewModel
    @State private var selectedRange: TimeRange = .week

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Loading history...")
            case .error(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.refresh() }
                }
            case .onboarding:
                EmptyView()
            case .loaded(let data):
                VStack(spacing: 0) {
                    Picker("Time Range", selection: $selectedRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(DesignSystem.Spacing.md)

                    let filtered = filterUsage(data.dailyUsage, range: selectedRange)

                    if filtered.isEmpty {
                        EmptyStateView(
                            title: "No History",
                            message: "No usage data for the selected time range."
                        )
                    } else {
                        List(filtered.reversed()) { row in
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(row.date)
                                    .font(.system(size: DesignSystem.Typography.bodyMedium))
                                    .fontWeight(.medium)

                                HStack {
                                    Label("DeepSeek: \(row.deepseekTokens) tokens", systemImage: "circle.fill")
                                        .font(.system(size: DesignSystem.Typography.captionSmall))
                                        .foregroundColor(DesignSystem.Color.deepseekAccent)
                                    Spacer()
                                    Text(String(format: "$%.2f", row.deepseekCost))
                                        .font(.system(size: DesignSystem.Typography.captionSmall))
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Label("MiniMax: \(row.minimaxTokens) tokens", systemImage: "circle.fill")
                                        .font(.system(size: DesignSystem.Typography.captionSmall))
                                        .foregroundColor(DesignSystem.Color.minimaxAccent)
                                    Spacer()
                                    Text(String(format: "$%.2f", row.minimaxCost))
                                        .font(.system(size: DesignSystem.Typography.captionSmall))
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Spacer()
                                    Text(String(format: "Total: $%.2f", row.totalCost))
                                        .font(.system(size: DesignSystem.Typography.captionSmall))
                                        .fontWeight(.medium)
                                }
                            }
                            .padding(.vertical, DesignSystem.Spacing.xs)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem {
                        Button("Refresh") {
                            Task { await viewModel.refresh() }
                        }
                    }
                }
            }
        }
    }

    private func filterUsage(_ usage: [DailyUsageRow], range: TimeRange) -> [DailyUsageRow] {
        guard range != .all else { return usage }
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -range.dayLimit, to: Date()) ?? Date()
        return usage.filter { row in
            guard let date = dateFromString(row.date) else { return true }
            return date >= cutoff
        }
    }

    private func dateFromString(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }
}
