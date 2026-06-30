import SwiftUI
import OpencodeWidgetShared

struct ContentView: View {
    @State private var showPreferences = false

    var body: some View {
        VStack {
            Button("Preferences...") {
                showPreferences.toggle()
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
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
    }
}
