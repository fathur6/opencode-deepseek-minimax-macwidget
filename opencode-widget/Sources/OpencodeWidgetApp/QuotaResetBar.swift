import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

/// Usage bar for the ChatGPT Plus quota card: the track fills proportional to
/// usage (e.g. ~1% glow when 99% remaining), and a thin vertical marker shows
/// the current position in the 168-hour reset cycle (elapsed hours since reset).
/// The marker is a pure function of `(resetDate, now)` and updates once per
/// minute via TimelineView — no network refresh required.
struct QuotaResetBar: View {
    let remainingPercent: Double?
    let resetDate: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let usedFraction = 1 - normalizedRemaining
            let markerFraction = resetDate.map { QuotaResetTimeline(resetDate: $0).elapsedFraction(at: now) } ?? 0

            GeometryReader { proxy in
                let width = proxy.size.width
                let fillWidth = width * usedFraction

                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: width, height: 4)

                    // Usage fill (glows proportionally to usage)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: max(2, fillWidth), height: 4)

                    // Moving vertical marker = elapsed hours in the 168h cycle
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 2, height: 8)
                        .position(x: min(width - 1, max(1, width * markerFraction)), y: 2)
                }
            }
            .frame(height: 8)
        }
    }

    private var normalizedRemaining: Double {
        guard let remainingPercent, remainingPercent.isFinite else { return 0 }
        return min(1, max(0, remainingPercent / 100))
    }
}
