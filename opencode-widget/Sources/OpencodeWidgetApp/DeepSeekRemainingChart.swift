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

struct RemainingQuotaSeries: Equatable {
    let colorName: String
}

struct RemainingQuotaChartProjection: Equatable {
    let deepseek: RemainingQuotaSeries
    let openAI: RemainingQuotaSeries
    let deepseekSnapshots: [DeepSeekBalanceSnapshot]
    let openAISnapshots: [OpenAIQuotaSnapshot]
    let balanceMarkers: [DeepSeekBalanceSnapshot]
    let percentMarkers: [OpenAIQuotaSnapshot]
    let topUps: [DeepSeekBalanceDelta]
    let consumption: [DeepSeekBalanceDelta]
    let xDomain: ClosedRange<Date>
    let deepseekRMYDomain: ClosedRange<Double>
    let openAIPercentYDomain: ClosedRange<Double>

    init(deepseekSnapshots: [DeepSeekBalanceSnapshot], openAISnapshots: [OpenAIQuotaSnapshot], xDomain: ClosedRange<Date>) {
        self.deepseek = RemainingQuotaSeries(colorName: "blue")
        self.openAI = RemainingQuotaSeries(colorName: "green")
        self.deepseekSnapshots = deepseekSnapshots
        self.openAISnapshots = openAISnapshots
        balanceMarkers = deepseekSnapshots
        percentMarkers = openAISnapshots
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
        let maxRM = max(1, deepseekSnapshots.map(\.remainingRM).max() ?? 0)
        deepseekRMYDomain = 0...(maxRM * 1.1)
        openAIPercentYDomain = 0...110
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Remaining Quota")
                .font(.caption)
                .foregroundStyle(.secondary)

            if deepseekSnapshots.isEmpty && openAISnapshots.isEmpty {
                Text("Unavailable")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(height: 92, alignment: .leading)
            } else {
                Chart {
                    ForEach(projection.deepseekSnapshots) { snapshot in
                        LineMark(
                            x: .value("Hour", snapshot.hour),
                            y: .value("Remaining RM", snapshot.remainingRM)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }

                    ForEach(projection.balanceMarkers) { snapshot in
                        PointMark(
                            x: .value("Hour", snapshot.hour),
                            y: .value("Remaining RM", snapshot.remainingRM)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(20)
                    }

                    ForEach(projection.topUps) { topUp in
                        BarMark(
                            x: .value("Hour", topUp.hour),
                            y: .value("Top up", topUp.amount)
                        )
                        .foregroundStyle(.green)
                    }

                    ForEach(projection.consumption) { event in
                        BarMark(
                            x: .value("Hour", event.hour),
                            y: .value("Consumption", event.amount)
                        )
                        .foregroundStyle(.gray)
                    }

                    ForEach(projection.openAISnapshots) { snapshot in
                        LineMark(
                            x: .value("Hour", snapshot.hour),
                            y: .value("Remaining Percent", snapshot.remainingPercent)
                        )
                        .foregroundStyle(.green)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }

                    ForEach(projection.percentMarkers) { snapshot in
                        PointMark(
                            x: .value("Hour", snapshot.hour),
                            y: .value("Remaining Percent", snapshot.remainingPercent)
                        )
                        .foregroundStyle(.green)
                        .symbolSize(20)
                    }
                }
                .chartXScale(domain: projection.xDomain)
                .chartYScale(domain: projection.deepseekRMYDomain)
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
                            if let remainingRM = value.as(Double.self) {
                                Text(remainingRM.formatted(.number.notation(.compactName).precision(.fractionLength(0))))
                                    .font(.system(size: 8, design: .monospaced))
                            }
                        }
                    }
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel {
                            if let percent = value.as(Double.self) {
                                Text(percent.formatted(.number.precision(.fractionLength(0))))
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
