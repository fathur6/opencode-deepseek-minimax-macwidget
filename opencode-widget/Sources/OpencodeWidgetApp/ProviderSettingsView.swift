import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

@MainActor
struct ProviderSettingsView: View {
    @State private var preferences: ProviderDisplayPreferences
    @State private var coordinator: ProviderSetupCoordinator
    @State private var expandedProviders: Set<ProviderID> = []
    @State private var candidateKeys: [ProviderID: String] = [:]

    @MainActor
    init(preferences: ProviderDisplayPreferences) {
        self.init(preferences: preferences, coordinator: ProviderSetupCoordinator())
    }

    @MainActor
    init(preferences: ProviderDisplayPreferences, coordinator: ProviderSetupCoordinator) {
        _preferences = State(initialValue: preferences)
        _coordinator = State(initialValue: coordinator)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Providers")
                    .font(.title2.weight(.semibold))
                Text("Choose cards for the menu and securely configure provider access.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ForEach(ProviderID.allCases, id: \.self) { provider in
                    providerRow(provider)
                    if provider != .openAI {
                        Divider()
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 440, idealWidth: 440, maxWidth: 440, minHeight: 300, maxHeight: 520)
    }

    @ViewBuilder
    private func providerRow(_ provider: ProviderID) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title(for: provider))
                        .font(.headline)
                    Text(statusText(for: provider))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Show card", isOn: visibilityBinding(for: provider))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("Show \(title(for: provider)) card")
            }

            switch provider {
            case .deepseek, .minimax:
                HStack(spacing: 8) {
                    Button(expandedProviders.contains(provider) ? "Hide setup" : "Configure") {
                        toggleSetup(for: provider)
                    }
                    .buttonStyle(.bordered)

                    Button("Remove", role: .destructive) {
                        Task { await coordinator.removeCredential(for: provider) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(coordinator.isSaving(provider))
                }

                if expandedProviders.contains(provider) {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("API key", text: candidateBinding(for: provider))
                            .textFieldStyle(.roundedBorder)
                            .disabled(coordinator.isSaving(provider))

                        HStack(spacing: 8) {
                            Button {
                                let candidate = candidateKeys[provider, default: ""]
                                Task { await coordinator.save(candidate: candidate, for: provider) }
                            } label: {
                                if coordinator.isSaving(provider) {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("Validate & Save")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(candidateKeys[provider, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || coordinator.isSaving(provider))

                            Text(coordinator.statusText(for: provider))
                                .font(.caption)
                                .foregroundStyle(statusColor(for: coordinator.status(for: provider)))
                        }
                    }
                }
            case .openAI:
                Text("ChatGPT Plus quota requires a Codex session. Copy the command, run it yourself, then reopen Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Copy codex login") {
                        coordinator.copyCodexLoginCommand()
                    }
                    .buttonStyle(.bordered)
                    Text("Copies a command only; it never starts authentication.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func visibilityBinding(for provider: ProviderID) -> Binding<Bool> {
        Binding(
            get: { preferences.isCardVisible(provider) },
            set: { preferences.setCardVisible($0, for: provider) }
        )
    }

    private func candidateBinding(for provider: ProviderID) -> Binding<String> {
        Binding(
            get: { candidateKeys[provider, default: ""] },
            set: { candidateKeys[provider] = $0 }
        )
    }

    private func toggleSetup(for provider: ProviderID) {
        if expandedProviders.contains(provider) {
            expandedProviders.remove(provider)
            candidateKeys[provider] = ""
        } else {
            expandedProviders.insert(provider)
        }
    }

    private func title(for provider: ProviderID) -> String {
        switch provider {
        case .deepseek: "DeepSeek"
        case .minimax: "MiniMax"
        case .openAI: "OpenAI"
        }
    }

    private func statusText(for provider: ProviderID) -> String {
        provider == .openAI ? coordinator.codexStatusText : coordinator.statusText(for: provider)
    }

    private func statusColor(for status: ProviderSetupStatus) -> Color {
        switch status {
        case .saved, .removed:
            .secondary
        case .validationFailed, .storageFailed:
            .red
        case .idle, .validating:
            .secondary
        }
    }
}
