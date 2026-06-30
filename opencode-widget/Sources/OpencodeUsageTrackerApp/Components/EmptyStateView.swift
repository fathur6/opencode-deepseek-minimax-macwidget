import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text(title)
                .font(.system(size: DesignSystem.Typography.headingMedium))
                .foregroundColor(.secondary)

            Text(message)
                .font(.system(size: DesignSystem.Typography.bodyMedium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let action, let actionLabel {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
