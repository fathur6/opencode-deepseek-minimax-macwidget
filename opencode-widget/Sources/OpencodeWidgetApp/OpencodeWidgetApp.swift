import SwiftUI
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
        MenuBarExtra {
            ContentView(menuState: menuState)
        } label: {
            let hasDS = menuState.deepseekBalance != nil
            let hasMM = menuState.minimaxBalance != nil
            switch (hasDS, hasMM) {
            case (true, true): Text("⬡◈")
            case (true, false): Text("⬡")
            case (false, true): Text("◈")
            case (false, false): Text("⬡").opacity(0.4)
            }
        }
        Settings {
            PreferencesView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            let cache = await DataFetcher.refreshAll()
            DataStore.save(cache: cache)
            await updateMenuState(with: cache)
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { _ in
            Task {
                let cache = await DataFetcher.refreshAll()
                DataStore.save(cache: cache)
                await self.updateMenuState(with: cache)
            }
        }
    }

    @MainActor
    private func updateMenuState(with cache: WidgetCache) {
        MenuBarState.shared.deepseekBalance = cache.deepseek.balance
        MenuBarState.shared.minimaxBalance = cache.minimax.balance
        MenuBarState.shared.lastUpdated = cache.lastUpdated
    }
}
