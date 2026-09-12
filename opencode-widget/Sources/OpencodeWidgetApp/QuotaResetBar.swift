import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

/// Usage bar for the ChatGPT Plus quota card: the track fills proportional to
/// usage (e.g. ~1% glow when 99% remaining), and a thin vertical marker shows
/// the current position in the supplied reset cycle (weekly by default).
/// The marker is a pure function of `(resetDate, now)` and updates once per
/// minute via TimelineView — no network refresh required.
struct QuotaResetBar: View {
    let remainingPercent: Double?
    let resetDate: Date?
    var cycleHours: Double = 168

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date

            GeometryReader { proxy in
                let width = proxy.size.width

                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: width, height: 4)

                    // Usage fill (glows proportionally to usage)
                    if let usedFraction, usedFraction > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.primary.opacity(0.85))
                            .frame(width: width * usedFraction, height: 4)
                    }

                    if let markerFraction = markerFraction(at: now) {
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 2, height: 8)
                            .position(x: min(width - 1, max(1, width * markerFraction)), y: 2)
                    }
                }
            }
            .frame(height: 8)
        }
    }

    var usedFraction: Double? {
        guard let remainingPercent, remainingPercent.isFinite,
              (0...100).contains(remainingPercent) else { return nil }
        return 1 - remainingPercent / 100
    }

    func markerFraction(at now: Date) -> Double? {
        guard let resetDate else { return nil }
        let timeline = QuotaResetTimeline(resetDate: resetDate, cycleHours: cycleHours)
        guard timeline.isValid(at: now) else { return nil }
        return timeline.elapsedFraction(at: now)
    }
}
