import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

@main
struct OpencodeWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Opencode Widget", systemImage: "chart.bar.fill") {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            let cache = await DataFetcher.refreshAll()
            DataStore.save(cache: cache)
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { _ in
            Task {
                let cache = await DataFetcher.refreshAll()
                DataStore.save(cache: cache)
            }
        }
    }
}
