import SwiftUI
import Charts
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct DeepSeekBalanceDelta: Identifiable, Equatable {
    let hour: Date
    let amount: Double
    let colorName: String

    var id: String { "\(hour.timeIntervalSince1970)-\(colorName)" }
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
    let topUps: [DeepSeekBalanceDelta]
    let consumption: [DeepSeekBalanceDelta]
    let xDomain: ClosedRange<Date>
    let plotYDomain: ClosedRange<Double>
    let rmAxisMax: Double
    let percentAxisMax: Double

    private static let deepseekSeriesKey = "DeepSeek"
    private static let openAISeriesKey = "OpenAI"

    init(deepseekSnapshots: [DeepSeekBalanceSnapshot], openAISnapshots: [OpenAIQuotaSnapshot], xDomain: ClosedRange<Date>) {
        deepseekSeriesColor = "blue"
        openAISeriesColor = "green"

        let maxRM = max(1, deepseekSnapshots.map(\.remainingRM).max() ?? 0)
        let maxPercent = max(1, openAISnapshots.map(\.remainingPercent).max() ?? 0)
        let rmAxisMax = maxRM * 1.1
        let percentAxisMax = 110.0

        deepseekPoints = deepseekSnapshots.map {
            RemainingQuotaChartPoint(series: Self.deepseekSeriesKey, hour: $0.hour, y: $0.remainingRM / rmAxisMax)
        }
        openAIPoints = openAISnapshots.map {
            RemainingQuotaChartPoint(series: Self.openAISeriesKey, hour: $0.hour, y: $0.remainingPercent / percentAxisMax)
        }

        var topUps: [DeepSeekBalanceDelta] = []
        var consumption: [DeepSeekBalanceDelta] = []
        for (previous, current) in zip(deepseekSnapshots, deepseekSnapshots.dropFirst()) {
            let delta = current.remainingRM - previous.remainingRM
            if delta > 0 { topUps.append(.init(hour: current.hour, amount: delta, colorName: "green")) }
            if delta < 0 { consumption.append(.init(hour: current.hour, amount: -delta, colorName: "gray")) }
        }

        self.topUps = topUps
        self.consumption = consumption
        self.xDomain = xDomain
        self.plotYDomain = 0...1
        self.rmAxisMax = rmAxisMax
        self.percentAxisMax = percentAxisMax
    }
}

struct RemainingQuotaChart: View {
    let deepseekSnapshots: [DeepSeekBalanceSnapshot]
    let openAISnapshots: [OpenAIQuotaSnapshot]
    let xDomain: ClosedRange<Date>

    private var projection: RemainingQuotaChartProjection {
        RemainingQuotaChartProjection(
            deepseekSnapshots: deepseekSnapshots,
            openAISnapshots: openAISnapshots,
            xDomain: xDomain
        )
    }

    func rmLabel(_ plotY: Double, axisMax: Double) -> String {
        (plotY * axisMax).formatted(.number.notation(.compactName).precision(.fractionLength(0)))
    }

    func percentLabel(_ plotY: Double, axisMax: Double) -> String {
        (plotY * axisMax).formatted(.number.precision(.fractionLength(0)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Remaining Quota")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                legend(name: "DeepSeek RM", color: .blue)
                legend(name: "OpenAI %", color: .green)
            }

            if deepseekSnapshots.isEmpty && openAISnapshots.isEmpty {
                Text("Unavailable")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(height: 92, alignment: .leading)
            } else {
                Chart {
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

                    ForEach(projection.deepseekPoints) { point in
                        PointMark(
                            x: .value("Hour", point.hour),
                            y: .value("Remaining", point.y)
                        )
                        .foregroundStyle(by: .value("Series", point.series))
                        .symbolSize(20)
                    }

                    ForEach(projection.openAIPoints) { point in
                        PointMark(
                            x: .value("Hour", point.hour),
                            y: .value("Remaining", point.y)
                        )
                        .foregroundStyle(by: .value("Series", point.series))
                        .symbolSize(20)
                    }

                    ForEach(projection.topUps) { topUp in
                        BarMark(
                            x: .value("Hour", topUp.hour),
                            yStart: .value("Zero", 0),
                            yEnd: .value("Top up", topUp.amount / projection.rmAxisMax)
                        )
                        .foregroundStyle(.green)
                    }

                    ForEach(projection.consumption) { event in
                        BarMark(
                            x: .value("Hour", event.hour),
                            yStart: .value("Zero", 0),
                            yEnd: .value("Consumption", event.amount / projection.rmAxisMax)
                        )
                        .foregroundStyle(.gray)
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
                                Text(rmLabel(plotY, axisMax: projection.rmAxisMax))
                                    .font(.system(size: 8, design: .monospaced))
                            }
                        }
                    }
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel {
                            if let plotY = value.as(Double.self) {
                                Text(percentLabel(plotY, axisMax: projection.percentAxisMax))
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
