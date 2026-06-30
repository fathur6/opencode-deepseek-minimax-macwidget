import SwiftUI

struct ProgressBar: View {
    let value: Double
    var height: CGFloat = 8

    private var barColor: Color {
        switch UsageStatus(usedPercentage: value) {
        case .safe: return DesignSystem.Color.safe
        case .warning: return DesignSystem.Color.warning
        case .critical: return DesignSystem.Color.critical
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(Color(.separatorColor).opacity(0.2))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(barColor)
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)), height: height)
            }
        }
        .frame(height: height)
    }
}
