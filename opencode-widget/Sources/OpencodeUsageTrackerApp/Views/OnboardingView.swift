import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    init(authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json", onComplete: @escaping () -> Void) {
        self._viewModel = State(initialValue: OnboardingViewModel(authPath: authPath))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("API Keys Required")
                .font(.system(size: DesignSystem.Typography.displayMedium))
                .fontWeight(.bold)

            Text("Enter your API keys to monitor usage.\nKeys are stored locally and never shared.")
                .font(.system(size: DesignSystem.Typography.bodyMedium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("DeepSeek API Key")
                        .font(.system(size: DesignSystem.Typography.caption))
                        .foregroundColor(.secondary)
                    SecureField("sk-...", text: $viewModel.deepseekKey)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("MiniMax API Key")
                        .font(.system(size: DesignSystem.Typography.caption))
                        .foregroundColor(.secondary)
                    SecureField("mm-...", text: $viewModel.minimaxKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .frame(maxWidth: 320)

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.system(size: DesignSystem.Typography.caption))
                    .foregroundColor(viewModel.statusMessage.contains("Error") ? DesignSystem.Color.critical : DesignSystem.Color.safe)
            }

            Button(action: {
                Task { await viewModel.verifyAndSave(onComplete: onComplete) }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Get Started")
                        .frame(maxWidth: 200)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.deepseekKey.isEmpty || viewModel.minimaxKey.isEmpty || viewModel.isLoading)
        }
        .padding(DesignSystem.Spacing.xxl)
        .frame(width: 400, height: 500)
    }
}
