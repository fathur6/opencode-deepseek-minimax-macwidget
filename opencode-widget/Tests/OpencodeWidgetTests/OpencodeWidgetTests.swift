import Testing
@testable import OpencodeWidget
import OpencodeWidgetShared

@Test func usageEntryCreation() {
    let cache = WidgetCache(lastUpdated: Date())
    let entry = UsageEntry(date: Date(), cache: cache)
    #expect(entry.cache.lastUpdated == cache.lastUpdated)
}
