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
        let dsText = menuState.deepseekBalance.map { String(format: "$%.2f", $0) }
        let mmText = menuState.minimaxBalance.map { String(format: "$%.2f", $0) }

        switch (dsText, mmText) {
        case let (ds?, mm?):
            Text("DS \(ds)  MM \(mm)")
        case let (ds?, nil):
            Text("DS \(ds)")
        case let (nil, mm?):
            Text("MM \(mm)")
        case (nil, nil):
            Text("")
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
