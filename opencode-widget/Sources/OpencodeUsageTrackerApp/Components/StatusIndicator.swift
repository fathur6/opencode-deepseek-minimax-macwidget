import SwiftUI

struct StatusIndicator: View {
    let status: UsageStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private var color: Color {
        switch status {
        case .safe: return DesignSystem.Color.safe
        case .warning: return DesignSystem.Color.warning
        case .critical: return DesignSystem.Color.critical
        }
    }
}
