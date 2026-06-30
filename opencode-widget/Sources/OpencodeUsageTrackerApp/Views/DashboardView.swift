import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct DashboardView: View {
    let viewModel: UsageViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Refreshing...")
            case .error(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.refresh() }
                }
            case .onboarding:
                EmptyView()
            case .loaded(let data):
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Stat cards
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                            StatCard(
                                title: "DeepSeek Balance",
                                value: data.deepseekBalance.map { String(format: "$%.2f", $0) } ?? "—",
                                icon: "dollarsign.circle.fill",
                                color: DesignSystem.Color.deepseekAccent
                            )
                            StatCard(
                                title: "MiniMax Prompts Left",
                                value: "\(data.minimaxModels.reduce(0) { $0 + $1.currentIntervalRemainingCount })",
                                icon: "number.circle.fill",
                                color: DesignSystem.Color.minimaxAccent
                            )
                            StatCard(
                                title: "Today's Tokens",
                                value: (data.dailyUsage.last?.totalTokens ?? 0).formattedNumber(),
                                icon: "chart.bar.fill",
                                color: .orange
                            )
                            StatCard(
                                title: "Active Models",
                                value: "\(data.minimaxModels.count + Set(data.perModelUsage.map(\.modelId)).count)",
                                icon: "cpu.fill",
                                color: .purple
                            )
                        }

                        // Trend chart
                        if !data.dailyUsage.isEmpty {
                            TimelineChart(dailyUsage: data.dailyUsage)
                                .padding()
                                .background(Color(.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(DesignSystem.Radius.lg)
                        }

                        // Last updated
                        HStack {
                            Spacer()
                            Text("Last updated: \(data.lastUpdated, style: .time)")
                                .font(.system(size: DesignSystem.Typography.captionSmall))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
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
}

extension Int {
    func formattedNumber() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
