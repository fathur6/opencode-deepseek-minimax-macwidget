import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct UsageView: View {
    let viewModel: UsageViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Loading usage...")
            case .error(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.refresh() }
                }
            case .onboarding:
                EmptyView()
            case .loaded(let data):
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        if !data.minimaxModels.isEmpty {
                            Text("MiniMax")
                                .font(.system(size: DesignSystem.Typography.headingLarge))
                                .fontWeight(.semibold)

                            ForEach(data.minimaxModels) { model in
                                ModelCard(
                                    modelName: model.modelName,
                                    provider: "MiniMax",
                                    totalPrompts: model.currentIntervalTotalCount,
                                    remainingPrompts: model.currentIntervalRemainingCount,
                                    tokens: 0,
                                    cost: 0
                                )
                            }
                        }

                        // Group per-model DB data by provider
                        let dsModels = data.perModelUsage.filter { $0.provider == "deepseek" }
                        let mmModels = data.perModelUsage.filter { $0.provider == "minimax" }

                        if !dsModels.isEmpty {
                            Text("DeepSeek")
                                .font(.system(size: DesignSystem.Typography.headingLarge))
                                .fontWeight(.semibold)

                            ForEach(aggregateByModel(models: dsModels), id: \.modelId) { agg in
                                ModelCard(
                                    modelName: agg.modelId,
                                    provider: "DeepSeek",
                                    totalPrompts: nil,
                                    remainingPrompts: nil,
                                    tokens: agg.tokens,
                                    cost: agg.cost
                                )
                            }
                        }

                        if !mmModels.isEmpty {
                            Text("MiniMax (DB History)")
                                .font(.system(size: DesignSystem.Typography.headingLarge))
                                .fontWeight(.semibold)

                            ForEach(aggregateByModel(models: mmModels), id: \.modelId) { agg in
                                ModelCard(
                                    modelName: agg.modelId,
                                    provider: "MiniMax",
                                    totalPrompts: nil,
                                    remainingPrompts: nil,
                                    tokens: agg.tokens,
                                    cost: agg.cost
                                )
                            }
                        }

                        if data.minimaxModels.isEmpty && dsModels.isEmpty && mmModels.isEmpty {
                            EmptyStateView(
                                title: "No Usage Data",
                                message: "Usage data will appear once you start using AI models.",
                                action: { Task { await viewModel.refresh() } },
                                actionLabel: "Refresh"
                            )
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

    private func aggregateByModel(models: [ModelUsageRow]) -> [(modelId: String, tokens: Int, cost: Double)] {
        var dict: [String: (tokens: Int, cost: Double)] = [:]
        for m in models {
            dict[m.modelId, default: (0, 0)].tokens += m.tokens
            dict[m.modelId, default: (0, 0)].cost += m.cost
        }
        return dict.map { ($0.key, $0.value.tokens, $0.value.cost) }
            .sorted { $0.modelId < $1.modelId }
    }
}
