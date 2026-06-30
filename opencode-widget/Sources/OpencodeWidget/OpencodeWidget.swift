import WidgetKit
import SwiftUI
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

struct UsageEntry: TimelineEntry {
    let date: Date
    let cache: WidgetCache
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), cache: WidgetCache(lastUpdated: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let cache = DataStore.load() ?? WidgetCache(lastUpdated: Date())
        completion(UsageEntry(date: Date(), cache: cache))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let cache = DataStore.load() ?? WidgetCache(lastUpdated: Date())
        let entry = UsageEntry(date: Date(), cache: cache)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

#if !SWIFT_PACKAGE
@main
#endif
struct OpencodeUsageWidget: Widget {
    let kind: String = "OpencodeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("AI Platform Usage")
        .description("Deepseek and MiniMax balance & token usage")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
