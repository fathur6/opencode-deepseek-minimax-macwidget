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
            menuBarLabel
        }
        Settings {
            PreferencesView()
        }
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            if menuState.deepseekBalance != nil {
                Image("deepseek-icon")
                    .resizable()
                    .frame(width: 14, height: 14)
            }
            if menuState.minimaxBalance != nil {
                Image("minimax-icon")
                    .resizable()
                    .frame(width: 14, height: 14)
            }
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
