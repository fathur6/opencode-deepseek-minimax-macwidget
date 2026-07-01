import SwiftUI
import AppKit
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct ContentView: View {
    let menuState: MenuBarState
    @State private var preferencesWindow: NSWindow?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                BalanceCard(
                    label: "DeepSeek",
                    amount: menuState.deepseekBalance,
                    subtitle: "USD"
                )
                BalanceCard(
                    label: "MiniMax",
                    amount: menuState.minimaxBalance,
                    subtitle: "USD"
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            Divider()
                .padding(.vertical, 8)

            SparklineView()
                .frame(height: 36)
                .padding(.horizontal, 12)

            Divider()
                .padding(.vertical, 6)

            VStack(spacing: 2) {
                Button(action: showPreferences) {
                    HStack {
                        Text("Preferences...")
                        Spacer()
                        Text("⌘,")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Button(action: refreshData) {
                    HStack {
                        Text("Refresh Widget Data")
                        Spacer()
                        Text("⌘R")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Divider()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    HStack {
                        Text("Quit")
                        Spacer()
                        Text("⌘Q")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .padding(.bottom, 6)
        }
        .frame(width: 220)
    }

    private func showPreferences() {
        if let window = preferencesWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PreferencesView())
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshData() {
        Task {
            let cache = await DataFetcher.refreshAll()
            DataStore.save(cache: cache)
            await MainActor.run {
                MenuBarState.shared.deepseekBalance = cache.deepseek.balance
                MenuBarState.shared.minimaxBalance = cache.minimax.balance
                MenuBarState.shared.lastUpdated = cache.lastUpdated
            }
        }
    }
}

struct BalanceCard: View {
    let label: String
    let amount: Double?
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(amount.map { String(format: "$%.2f", $0) } ?? "--")
                .font(.headline)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(6)
    }
}

struct SparklineView: View {
    @State private var usage: [DailyUsageRow] = []

    var body: some View {
        GeometryReader { geo in
            let maxVal = Swift.max(usage.map(\.totalTokens).max() ?? 1, 1)
            let w = (geo.size.width - 4) / CGFloat(Swift.max(usage.count, 1))
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(usage.suffix(5))) { row in
                    let h = max(CGFloat(row.totalTokens) / CGFloat(maxVal) * geo.size.height, 2)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary.opacity(0.5))
                        .frame(width: max(w - 2, 4), height: h)
                }
            }
        }
        .onAppear {
            usage = DataStore.load()?.dailyUsage ?? []
        }
    }
}
