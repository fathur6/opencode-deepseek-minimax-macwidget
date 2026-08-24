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
    let tokens: Double
}

struct UsageHistoryChartSeries: Equatable, Sendable {
    let provider: UsageChartProvider
    let colorName: String
    let points: [UsageHistoryChartPoint]
}

struct UsageHistoryChartProjection: Equatable, Sendable {
    let series: [UsageHistoryChartSeries]
    let yDomain: ClosedRange<Double>
    let xDomain: ClosedRange<Date>

    init(buckets: [HourlyUsageBucket], xDomain: ClosedRange<Date>) {
        let openAI = buckets.map {
            UsageHistoryChartPoint(provider: .openAI, hour: $0.hour, tokens: max(0, $0.smoothedOpenAIInputTokens))
        }
        let deepseek = buckets.map {
            UsageHistoryChartPoint(provider: .deepseek, hour: $0.hour, tokens: max(0, $0.smoothedDeepseekInputTokens))
        }
        series = [
            UsageHistoryChartSeries(provider: .openAI, colorName: "green", points: openAI),
            UsageHistoryChartSeries(provider: .deepseek, colorName: "blue", points: deepseek)
        ]
        let maximum = max(1, (openAI + deepseek).map(\.tokens).filter(\.isFinite).max() ?? 0)
        yDomain = 0...(maximum * 1.1)
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
                Text("Usage · 168h")
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
                        y: .value("Input tokens", point.tokens),
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
