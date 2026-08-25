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
    var openAIEstimatedCost = 0.0
    var hourlyUsage: [HourlyUsageBucket] = []
    var deepseekBalanceHistory: [DeepSeekBalanceSnapshot] = []
    var openAIQuotaHistory: [OpenAIQuotaSnapshot] = []
    var lastUpdated: Date?
    private let estimatedCost: @MainActor (Date) -> Double

    init(estimatedCost: @escaping @MainActor (Date) -> Double = { resetDate in
        QuotaLedgerService.shared.activeOpenAIEstimatedCost(resetDate: resetDate)
    }) {
        self.estimatedCost = estimatedCost
    }

    func update(with cache: WidgetCache) {
        deepseekBalance = cache.deepseek.balance
        minimaxBalance = cache.minimax.balance
        openAIQuota = cache.openAIQuota
        if let resetDate = cache.openAIQuota?.resetDate {
            openAIEstimatedCost = estimatedCost(resetDate)
        }
        hourlyUsage = cache.hourlyUsage
        deepseekBalanceHistory = cache.deepseekBalanceHistory
        openAIQuotaHistory = cache.openAIQuotaHistory
        lastUpdated = cache.lastUpdated
    }
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
            QuotaLedgerService.shared.recordRefresh(cache: cache)
            await QuotaLedgerService.shared.runMonthlyReportIfDue()
            let seeded = QuotaLedgerService.shared.seededCache(from: cache)
            DataStore.save(cache: seeded)
            guard let self else { return }
            updateMenuState(with: seeded)
            updateStatusIcon()
        }
    }

    private func updateMenuState(with cache: WidgetCache) {
        MenuBarState.shared.update(with: cache)
    }
}

@MainActor
struct MenuContent: View {
    @State private var menuState = MenuBarState.shared
    @State private var chartOffsetHours = 0

    static func quotaText(_ quota: OpenAIQuota?) -> String {
        guard let percent = quota?.remainingPercent else { return "Quota unavailable" }
        return String(format: "%.0f%% remaining", percent)
    }

    static func resetText(_ date: Date?) -> String {
        guard let date else { return "" }
        return "Resets " + date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    static func estimatedCostText(_ cost: Double) -> String {
        String(format: "Est. $%.2f", cost)
    }

    static func elapsedText(resetDate: Date?, now: Date = Date()) -> String? {
        guard let resetDate else { return nil }
        let hours = QuotaResetTimeline(resetDate: resetDate).elapsedHours(at: now)
        return String(format: "%.0fh of 168h", hours)
    }

    static func previousOffset(current: Int, historyCount: Int) -> Int {
        min(current + ChartWindow.stepHours, ChartWindow.maximumOffset(for: historyCount))
    }

    static func nextOffset(current: Int) -> Int {
        max(0, current - ChartWindow.stepHours)
    }

    var body: some View {
        let historyCount = menuState.hourlyUsage.count
        let newestHour = menuState.hourlyUsage.last?.hour ?? Date()
        let chartRange = ChartWindow.range(endingAt: newestHour, offsetHours: chartOffsetHours)
        let usageBuckets = menuState.hourlyUsage.filter { chartRange.contains($0.hour) }
        let balanceSnapshots = menuState.deepseekBalanceHistory.filter { chartRange.contains($0.hour) }
        let openAISnapshots = menuState.openAIQuotaHistory.filter { chartRange.contains($0.hour) }

        VStack(spacing: 0) {
            HStack(spacing: 8) {
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
                    HStack {
                        Text("OpenAI").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(Self.estimatedCostText(menuState.openAIEstimatedCost))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Text(Self.quotaText(menuState.openAIQuota))
                        .font(.headline).fontWeight(.semibold).monospacedDigit()
                    QuotaResetBar(
                        remainingPercent: menuState.openAIQuota?.remainingPercent,
                        resetDate: menuState.openAIQuota?.resetDate
                    )
                    .padding(.top, 2)
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

            HStack {
                Button {
                    chartOffsetHours = Self.previousOffset(current: chartOffsetHours, historyCount: historyCount)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .disabled(chartOffsetHours == ChartWindow.maximumOffset(for: historyCount))

                Spacer()

                Button {
                    chartOffsetHours = Self.nextOffset(current: chartOffsetHours)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(chartOffsetHours == 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            UsageHistoryChart(buckets: usageBuckets, xDomain: chartRange)
                .padding(.horizontal, 12)
                .padding(.top, 4)

            RemainingQuotaChart(deepseekSnapshots: balanceSnapshots, openAISnapshots: openAISnapshots, xDomain: chartRange)
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
        .onChange(of: menuState.hourlyUsage) { _, history in
            chartOffsetHours = min(chartOffsetHours, ChartWindow.maximumOffset(for: history.count))
        }
    }

    private static let usdToMYR: Double = 4.5

    private func balanceCard(title: String, balance: Double?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundColor(.secondary)
                if let balance {
                    Text(String(format: "$%.2f", balance))
                        .font(.headline).fontWeight(.semibold).monospacedDigit()
                    Text(String(format: "RM%.2f", balance * Self.usdToMYR))
                        .font(.caption2).foregroundColor(.secondary).monospacedDigit()
                } else {
                    Text("--").font(.headline).fontWeight(.semibold).monospacedDigit()
                    Text("RM--").font(.caption2).foregroundColor(.secondary)
                }
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
            QuotaLedgerService.shared.recordRefresh(cache: cache)
            await QuotaLedgerService.shared.runMonthlyReportIfDue()
            let seeded = QuotaLedgerService.shared.seededCache(from: cache)
            DataStore.save(cache: seeded)
            MenuBarState.shared.update(with: seeded)
        }
    }
}
