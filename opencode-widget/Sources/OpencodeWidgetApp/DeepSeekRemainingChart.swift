import SwiftUI
import Charts
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct CombinedConsumptionPoint: Identifiable, Equatable {
    let hour: Date
    let tokens: Int64
    let y: Double

    var id: Date { hour }
}

struct RemainingQuotaChartPoint: Identifiable, Equatable {
    let series: String
    let hour: Date
    let y: Double

    var id: String { "\(series)-\(hour.timeIntervalSince1970)" }
}

struct RemainingQuotaChartProjection: Equatable {
    let deepseekSeriesColor: String
    let openAISeriesColor: String
    let deepseekPoints: [RemainingQuotaChartPoint]
    let openAIPoints: [RemainingQuotaChartPoint]
    let consumption: [CombinedConsumptionPoint]
    let xDomain: ClosedRange<Date>
    let plotYDomain: ClosedRange<Double>
    let usdAxisMax: Double
    let percentAxisMax: Double

    private static let deepseekSeriesKey = "DeepSeek"
    private static let openAISeriesKey = "OpenAI"

    init(
        deepseekSnapshots: [DeepSeekBalanceSnapshot],
        openAISnapshots: [OpenAIQuotaSnapshot],
        hourlyUsage: [HourlyUsageBucket] = [],
        xDomain: ClosedRange<Date>
    ) {
        deepseekSeriesColor = "blue"
        openAISeriesColor = "green"

        let usdToMYR = DeepSeekBalanceHistory.usdToMYR
        let maxUSD = max(1, deepseekSnapshots.map { $0.remainingRM / usdToMYR }.max() ?? 0)
        let usdAxisMax = maxUSD * 1.1
        let percentAxisMax = 100.0

        deepseekPoints = deepseekSnapshots.map {
            RemainingQuotaChartPoint(series: Self.deepseekSeriesKey, hour: $0.hour, y: ($0.remainingRM / usdToMYR) / usdAxisMax)
        }
        openAIPoints = openAISnapshots.map {
            RemainingQuotaChartPoint(series: Self.openAISeriesKey, hour: $0.hour, y: $0.remainingPercent / percentAxisMax)
        }

        let combinedTokens = hourlyUsage.map {
            max(Int64(0), $0.deepseekInputTokens) + max(Int64(0), $0.openAIInputTokens)
        }
        let maximumCombinedTokens = combinedTokens.max() ?? 0
        let consumptionScale = maximumCombinedTokens > 0
            ? Double(maximumCombinedTokens) * 3
            : 1
        consumption = zip(hourlyUsage, combinedTokens).map { bucket, tokens in
            CombinedConsumptionPoint(
                hour: bucket.hour,
                tokens: tokens,
                y: Double(tokens) / consumptionScale
            )
        }
        self.xDomain = xDomain
        self.plotYDomain = 0...1
        self.usdAxisMax = usdAxisMax
        self.percentAxisMax = percentAxisMax
    }
}

struct RemainingQuotaChart: View {
    let deepseekSnapshots: [DeepSeekBalanceSnapshot]
    let openAISnapshots: [OpenAIQuotaSnapshot]
    let hourlyUsage: [HourlyUsageBucket]
    let xDomain: ClosedRange<Date>

    private var projection: RemainingQuotaChartProjection {
        RemainingQuotaChartProjection(
            deepseekSnapshots: deepseekSnapshots,
            openAISnapshots: openAISnapshots,
            hourlyUsage: hourlyUsage,
            xDomain: xDomain
        )
    }

    func usdLabel(_ plotY: Double, axisMax: Double) -> String {
        "$" + (plotY * axisMax).formatted(.number.notation(.compactName).precision(.fractionLength(0)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Quota")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                legend(name: "DeepSeek", color: .blue)
                legend(name: "OpenAI", color: .green)
            }

            if deepseekSnapshots.isEmpty && openAISnapshots.isEmpty {
                Text("Unavailable")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(height: 92, alignment: .leading)
            } else {
                Chart {
                    ForEach(projection.consumption) { point in
                        BarMark(
                            x: .value("Hour", point.hour),
                            yStart: .value("Zero", 0),
                            yEnd: .value("Combined input tokens", point.y)
                        )
                        .foregroundStyle(.gray)
                    }

                    ForEach(projection.deepseekPoints) { point in
                        LineMark(
                            x: .value("Hour", point.hour),
                            y: .value("Remaining", point.y),
                            series: .value("Series", point.series)
                        )
                        .foregroundStyle(by: .value("Series", point.series))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }

                    ForEach(projection.openAIPoints) { point in
                        LineMark(
                            x: .value("Hour", point.hour),
                            y: .value("Remaining", point.y),
                            series: .value("Series", point.series)
                        )
                        .foregroundStyle(by: .value("Series", point.series))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }

                }
                .chartForegroundStyleScale([
                    "DeepSeek": Color.blue,
                    "OpenAI": Color.green
                ])
                .chartLegend(.hidden)
                .chartXScale(domain: projection.xDomain)
                .chartYScale(domain: projection.plotYDomain)
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
                            if let plotY = value.as(Double.self) {
                                Text(usdLabel(plotY, axisMax: projection.usdAxisMax))
                                    .font(.system(size: 8, design: .monospaced))
                            }
                        }
                    }
                }
                .frame(height: 92)
            }
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
        let startOfDay = calendar.startOfDay(for: projection.xDomain.lowerBound)
        let firstVisibleDay = startOfDay < projection.xDomain.lowerBound
            ? calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            : startOfDay
        return calendar.isDate(date, inSameDayAs: firstVisibleDay)
            || calendar.component(.day, from: date) == 1
    }
}
