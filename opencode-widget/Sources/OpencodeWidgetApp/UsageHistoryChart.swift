import SwiftUI
import Charts
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

enum UsageChartProvider: String, CaseIterable, Equatable, Sendable {
    case openAI = "OpenAI"
    case deepseek = "DeepSeek"
}

struct UsageHistoryChartPoint: Identifiable, Equatable, Sendable {
    var id: String { "\(provider.rawValue)-\(hour.timeIntervalSince1970)" }
    let provider: UsageChartProvider
    let hour: Date
    /// Real observed token count; used by accessibility and tests.
    let tokens: Double
    /// Value used for the plotted height. DeepSeek plots on the visible
    /// leading y-axis; OpenAI is rescaled onto its own hidden auto-max y2-axis.
    let plotTokens: Double
}

struct UsageHistoryChartSeries: Equatable, Sendable {
    let provider: UsageChartProvider
    let colorName: String
    let points: [UsageHistoryChartPoint]
}

struct UsageHistoryChartProjection: Equatable, Sendable {
    let series: [UsageHistoryChartSeries]
    /// Visible leading y-axis domain, describing the DeepSeek token scale.
    let yDomain: ClosedRange<Double>
    let xDomain: ClosedRange<Date>
    /// Auto-max of each provider, exposed for the hidden second axis and tests.
    let deepseekMaxTokens: Double
    let openAIMaxTokens: Double

    init(buckets: [HourlyUsageBucket], xDomain: ClosedRange<Date>) {
        func finite(_ value: Double) -> Double {
            value.isFinite ? max(0, value) : 0
        }
        let openAITokens = buckets.map { finite($0.smoothedOpenAIInputTokens) }
        let deepseekTokens = buckets.map { finite($0.smoothedDeepseekInputTokens) }

        // Each provider gets its own zero-based auto-max. DeepSeek drives the
        // visible leading axis; OpenAI is normalised against its own maximum and
        // drawn on the hidden second axis so a small series stays legible.
        let deepseekMax = max(1, deepseekTokens.max() ?? 0)
        let openAIMax = max(1, openAITokens.max() ?? 0)
        deepseekMaxTokens = deepseekMax
        openAIMaxTokens = openAIMax

        let openAI = zip(buckets, openAITokens).map { bucket, tokens in
            UsageHistoryChartPoint(
                provider: .openAI,
                hour: bucket.hour,
                tokens: tokens,
                plotTokens: tokens / openAIMax * deepseekMax
            )
        }
        let deepseek = zip(buckets, deepseekTokens).map { bucket, tokens in
            UsageHistoryChartPoint(provider: .deepseek, hour: bucket.hour, tokens: tokens, plotTokens: tokens)
        }
        series = [
            UsageHistoryChartSeries(provider: .openAI, colorName: "green", points: openAI),
            UsageHistoryChartSeries(provider: .deepseek, colorName: "blue", points: deepseek)
        ]
        yDomain = 0...(deepseekMax * 1.1)
        self.xDomain = xDomain
    }
}

struct UsageHistoryChart: View {
    let buckets: [HourlyUsageBucket]
    let xDomain: ClosedRange<Date>

    private var projection: UsageHistoryChartProjection {
        UsageHistoryChartProjection(buckets: buckets, xDomain: xDomain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                legend(name: "DeepSeek", color: .blue)
                legend(name: "OpenAI", color: .green)
            }

            Chart(projection.series, id: \.provider) { series in
                ForEach(series.points) { point in
                    LineMark(
                        x: .value("Hour", point.hour),
                        y: .value("Input tokens", point.plotTokens),
                        series: .value("Provider", series.provider.rawValue)
                    )
                    .foregroundStyle(by: .value("Provider", series.provider.rawValue))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .accessibilityLabel("\(series.provider.rawValue), \(point.hour.formatted(date: .abbreviated, time: .shortened))")
                    .accessibilityValue("\(Int(point.tokens.rounded()).formatted(.number.notation(.compactName))) input tokens")
                }
            }
            .chartForegroundStyleScale([
                UsageChartProvider.openAI.rawValue: Color.green,
                UsageChartProvider.deepseek.rawValue: Color.blue
            ])
            .chartLegend(.hidden)
            .chartXScale(domain: projection.xDomain)
            .chartYScale(domain: projection.yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            VStack(spacing: 1) {
                                Text(date.formatted(.dateTime.day()))
                                    .font(.system(size: 7, design: .monospaced))
                                Text(showsMonth(for: date) ? date.formatted(.dateTime.month(.abbreviated)) : " ")
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel {
                        if let tokens = value.as(Double.self) {
                            Text(tokens.formatted(.number.notation(.compactName).precision(.fractionLength(0))))
                                .font(.system(size: 8, design: .monospaced))
                        }
                    }
                }
            }
            .frame(height: 92)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(6)
    }

    private func legend(name: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(name).font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func showsMonth(for date: Date) -> Bool {
        let calendar = Calendar.current
        let domainStart = projection.xDomain.lowerBound
        let startOfDay = calendar.startOfDay(for: domainStart)
        let firstVisibleDay = startOfDay < domainStart
            ? calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            : startOfDay
        return calendar.isDate(date, inSameDayAs: firstVisibleDay)
            || calendar.component(.day, from: date) == 1
    }
}
