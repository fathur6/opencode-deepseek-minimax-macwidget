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

struct DeepSeekRemainingChartProjection: Equatable {
    let snapshots: [DeepSeekBalanceSnapshot]
    let topUps: [DeepSeekBalanceDelta]
    let consumption: [DeepSeekBalanceDelta]
    let xDomain: ClosedRange<Date>
    let remainingDomain: ClosedRange<Double>

    init(snapshots: [DeepSeekBalanceSnapshot], xDomain: ClosedRange<Date>) {
        self.snapshots = snapshots
        var topUps: [DeepSeekBalanceDelta] = []
        var consumption: [DeepSeekBalanceDelta] = []

        for (previous, current) in zip(snapshots, snapshots.dropFirst()) {
            let delta = current.remainingRM - previous.remainingRM
            if delta > 0 {
                topUps.append(.init(hour: current.hour, amount: delta, colorName: "green"))
            }
            if delta < 0 {
                consumption.append(.init(hour: current.hour, amount: -delta, colorName: "gray"))
            }
        }

        self.topUps = topUps
        self.consumption = consumption
        self.xDomain = xDomain
        let maximum = max(1, snapshots.map(\.remainingRM).max() ?? 0)
        remainingDomain = 0...(maximum * 1.1)
    }
}

struct DeepSeekRemainingChart: View {
    let snapshots: [DeepSeekBalanceSnapshot]
    let xDomain: ClosedRange<Date>

    private var projection: DeepSeekRemainingChartProjection {
        DeepSeekRemainingChartProjection(snapshots: snapshots, xDomain: xDomain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DeepSeek remaining (RM)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if snapshots.isEmpty {
                Text("Unavailable")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(height: 92, alignment: .leading)
            } else {
                Chart {
                    ForEach(projection.snapshots) { snapshot in
                        LineMark(
                            x: .value("Hour", snapshot.hour),
                            y: .value("Remaining RM", snapshot.remainingRM)
                        )
                        .foregroundStyle(.green)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
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
                }
                .chartXScale(domain: projection.xDomain)
                .chartYScale(domain: projection.remainingDomain)
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
