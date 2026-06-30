import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct PreferencesView: View {
    @AppStorage("minimaxBalance", store: UserDefaults(suiteName: "group.com.opencode.widget"))
    private var minimaxBalance: String = ""

    @State private var refreshStatus = ""

    var body: some View {
        Form {
            Section("MiniMax Balance") {
                TextField("Enter balance (e.g. 5.00)", text: $minimaxBalance)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: minimaxBalance) {
                        updateWidgetCache()
                    }
            }

            Section("Deepseek") {
                Text("Auto-fetched from API")
                    .foregroundColor(.secondary)
            }

            Section {
                Button("Refresh Now") {
                    Task {
                        refreshStatus = "Refreshing..."
                        let cache = await DataFetcher.refreshAll()
                        DataStore.save(cache: cache)
                        refreshStatus = "Updated at \(Date().formatted(date: .omitted, time: .shortened))"
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
        .frame(width: 380, height: 300)
    }

    private func updateWidgetCache() {
        let existing = DataStore.load()
        let balance = Double(minimaxBalance.replacingOccurrences(of: "$", with: ""))
        let cache = WidgetCache(
            lastUpdated: Date(),
            deepseek: existing?.deepseek ?? ProviderBalance(),
            minimax: ProviderBalance(balance: balance, currency: "USD"),
            minimaxUsage: existing?.minimaxUsage,
            dailyUsage: existing?.dailyUsage ?? []
        )
        DataStore.save(cache: cache)
    }
}
