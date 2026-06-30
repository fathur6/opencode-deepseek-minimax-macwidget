import SwiftUI

struct ErrorStateView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(DesignSystem.Color.critical)

            Text("Error")
                .font(.system(size: DesignSystem.Typography.headingMedium))
                .foregroundColor(.primary)

            Text(message)
                .font(.system(size: DesignSystem.Typography.bodyMedium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Button("Retry", action: retryAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
