import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct ContentView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack {
            Button("Preferences...") {
                openSettings()
            }
            Button("Refresh Widget Data") {
                Task {
                    let cache = await DataFetcher.refreshAll()
                    DataStore.save(cache: cache)
                }
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
    }
}
