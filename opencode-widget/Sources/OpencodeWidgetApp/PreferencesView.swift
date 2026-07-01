import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct PreferencesView: View {
    @State private var minimaxCreditText: String = ""
    @State private var minimaxAutoFetch: Bool = true
    @State private var refreshStatus: String = ""
    @State private var savedText: String = ""

    private let defaults = UserDefaults(suiteName: "group.com.opencode.widget")

    var body: some View {
        Form {
            Section("MiniMax Credit (USD)") {
                HStack {
                    TextField("Enter credit amount", text: $minimaxCreditText)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Auto", isOn: $minimaxAutoFetch)
                        .toggleStyle(.switch)
                        .help("Fetch from API automatically")
                }

                if minimaxCreditText != savedText {
                    HStack {
                        Button("Cancel") {
                            minimaxCreditText = savedText
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            if !refreshStatus.isEmpty {
                                Text(refreshStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Button("Save") {
                                saveMinimaxCredit()
                            }
                            .keyboardShortcut(.return, modifiers: [])
                            .disabled(minimaxCreditText.isEmpty)
                        }
                    }
                }
            }

            Section("DeepSeek") {
                Text("Auto-fetched from API")
                    .foregroundColor(.secondary)
            }

            Section {
                Button("Refresh Widget Data") {
                    Task {
                        refreshStatus = "Refreshing..."
                        let cache = await DataFetcher.refreshAll()
                        DataStore.save(cache: cache)
                        refreshStatus = "Updated"
                    }
                }

                if !refreshStatus.isEmpty {
                    Text(refreshStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 260)
        .onAppear { loadPrefs() }
    }

    private func loadPrefs() {
        minimaxAutoFetch = defaults?.bool(forKey: "minimaxAutoFetch") ?? true
        if let val = defaults?.double(forKey: "minimaxCredit"), val > 0 {
            minimaxCreditText = String(format: "%.2f", val)
            savedText = minimaxCreditText
        }
    }

    private func saveMinimaxCredit() {
        guard let val = Double(minimaxCreditText) else { return }
        defaults?.set(val, forKey: "minimaxCredit")
        defaults?.set(minimaxAutoFetch, forKey: "minimaxAutoFetch")
        savedText = minimaxCreditText
        refreshStatus = "Saved"
    }
}
