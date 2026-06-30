import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .accentColor

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            Text(value)
                .font(.system(size: DesignSystem.Typography.headingLarge))
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: DesignSystem.Typography.caption))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(DesignSystem.Radius.md)
    }
}
