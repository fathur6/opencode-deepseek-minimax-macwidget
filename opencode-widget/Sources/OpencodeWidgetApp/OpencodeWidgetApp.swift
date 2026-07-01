import SwiftUI
import AppKit
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

@Observable
class MenuBarState {
    static let shared = MenuBarState()
    var deepseekBalance: Double?
    var minimaxBalance: Double?
    var lastUpdated: Date?
}

@main
struct OpencodeWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var menuState = MenuBarState.shared

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        buildMenu()

        Task {
            let cache = await DataFetcher.refreshAll()
            DataStore.save(cache: cache)
            await updateMenuState(with: cache)
            await MainActor.run { updateStatusIcon() }
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                let cache = await DataFetcher.refreshAll()
                DataStore.save(cache: cache)
                await self.updateMenuState(with: cache)
                await MainActor.run { self.updateStatusIcon() }
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

    @MainActor
    private func updateMenuState(with cache: WidgetCache) {
        MenuBarState.shared.deepseekBalance = cache.deepseek.balance
        MenuBarState.shared.minimaxBalance = cache.minimax.balance
        MenuBarState.shared.lastUpdated = cache.lastUpdated
    }
}

struct MenuContent: View {
    @State private var menuState = MenuBarState.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { NSWorkspace.shared.open(URL(string: "https://platform.deepseek.com/usage")!) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DeepSeek").font(.caption).foregroundColor(.secondary)
                        Text(menuState.deepseekBalance.map { String(format: "$%.2f", $0) } ?? "--")
                            .font(.headline).fontWeight(.semibold).monospacedDigit()
                        Text("USD").font(.caption2).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(6)

                Button(action: { NSWorkspace.shared.open(URL(string: "https://platform.minimax.io/console/recharge-records?operation=RECHARGE&type=SUCCESS")!) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MiniMax").font(.caption).foregroundColor(.secondary)
                        Text(menuState.minimaxBalance.map { String(format: "$%.2f", $0) } ?? "--")
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
            .padding(.horizontal, 12)
            .padding(.top, 10)

            Divider().padding(.vertical, 8)

            VStack(spacing: 2) {
                Button("Preferences...") { showPreferencesWindow() }
                    .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 4)
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

    private func showPreferencesWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.title = "Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PreferencesView())
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
