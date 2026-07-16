import SwiftUI
import AppKit
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

@Observable
@MainActor
class MenuBarState {
    static let shared = MenuBarState()
    var deepseekBalance: Double?
    var minimaxBalance: Double?
    var openAIQuota: OpenAIQuota?
    var lastUpdated: Date?
}

@main
struct OpencodeWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        buildMenu()

        refreshData()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshData()
            }
        }
    }

    private func loadIcon(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Resources") else { return nil }
        return NSImage(contentsOf: url)
    }

    private func updateStatusIcon() {
        let state = MenuBarState.shared

        guard let dsIcon = loadIcon("deepseek"),
              let mmIcon = loadIcon("minimax") else {
            statusItem.button?.attributedTitle = NSAttributedString(string: "#")
            return
        }

        let size: CGFloat = 14
        let gap: CGFloat = 2
        let totalWidth = size * 2 + gap
        let img = NSImage(size: NSSize(width: totalWidth, height: size))
        img.lockFocus()
        dsIcon.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        mmIcon.draw(in: NSRect(x: size + gap, y: 0, width: size, height: size))
        img.unlockFocus()
        img.isTemplate = state.deepseekBalance != nil || state.minimaxBalance != nil

        statusItem.button?.image = img
        statusItem.button?.imagePosition = .imageOnly
    }

    private func buildMenu() {
        let menu = NSMenu()
        let item = NSMenuItem()
        let host = NSHostingView(rootView: MenuContent())

        host.frame.size = host.fittingSize
        host.autoresizingMask = [.width, .height]
        item.view = host

        menu.addItem(item)
        statusItem.menu = menu
        statusItem.button?.sendAction(on: .leftMouseDown)
        statusItem.button?.target = nil
        statusItem.button?.action = nil
    }

    private func refreshData() {
        Task { [weak self] in
            let cache = await DataFetcher.refreshAll()
            DataStore.save(cache: cache)
            guard let self else { return }
            updateMenuState(with: cache)
            updateStatusIcon()
        }
    }

    private func updateMenuState(with cache: WidgetCache) {
        MenuBarState.shared.deepseekBalance = cache.deepseek.balance
        MenuBarState.shared.minimaxBalance = cache.minimax.balance
        MenuBarState.shared.openAIQuota = cache.openAIQuota
        MenuBarState.shared.lastUpdated = cache.lastUpdated
    }
}

@MainActor
struct MenuContent: View {
    @State private var menuState = MenuBarState.shared

    static func quotaText(_ quota: OpenAIQuota?) -> String {
        guard let percent = quota?.remainingPercent else { return "Quota unavailable" }
        return String(format: "%.0f%% remaining", percent)
    }

    static func resetText(_ date: Date?) -> String {
        guard let date else { return "" }
        return "Resets " + date.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                balanceCard(title: "DeepSeek", balance: menuState.deepseekBalance) {
                    NSWorkspace.shared.open(URL(string: "https://platform.deepseek.com/usage")!)
                }
                balanceCard(title: "MiniMax", balance: menuState.minimaxBalance) {
                    NSWorkspace.shared.open(URL(string: "https://platform.minimax.io/console/recharge-records?operation=RECHARGE&type=SUCCESS")!)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            Button(action: {
                NSWorkspace.shared.open(URL(string: "https://chatgpt.com/usage")!)
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenAI").font(.caption).foregroundColor(.secondary)
                    Text(Self.quotaText(menuState.openAIQuota))
                        .font(.headline).fontWeight(.semibold).monospacedDigit()
                    Text(Self.resetText(menuState.openAIQuota?.resetDate))
                        .font(.caption2).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            .buttonStyle(.plain)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider().padding(.vertical, 8)

            VStack(spacing: 2) {
                Button("Refresh") { refreshData() }
                    .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 4).keyboardShortcut("r")
                Divider()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 4).keyboardShortcut("q")
            }
            .padding(.bottom, 6)
        }
        .frame(width: 220)
    }

    private func balanceCard(title: String, balance: Double?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(balance.map { String(format: "$%.2f", $0) } ?? "--")
                    .font(.headline).fontWeight(.semibold).monospacedDigit()
                Text("USD").font(.caption2).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(6)
    }

    private func refreshData() {
        Task {
            let cache = await DataFetcher.refreshAll()
            DataStore.save(cache: cache)
            MenuBarState.shared.deepseekBalance = cache.deepseek.balance
            MenuBarState.shared.minimaxBalance = cache.minimax.balance
            MenuBarState.shared.openAIQuota = cache.openAIQuota
            MenuBarState.shared.lastUpdated = cache.lastUpdated
        }
    }
}
