import Foundation
import Observation
import UserNotifications
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

public enum ViewState: Equatable {
    case loading
    case loaded(UsageData)
    case error(String)
    case onboarding
}

public struct UsageData: Equatable {
    public let deepseekBalance: Double?
    public let minimaxModels: [MiniMaxModelRemain]
    public let dailyUsage: [DailyUsageRow]
    public let perModelUsage: [ModelUsageRow]
    public let lastUpdated: Date

    public init(deepseekBalance: Double? = nil, minimaxModels: [MiniMaxModelRemain] = [], dailyUsage: [DailyUsageRow] = [], perModelUsage: [ModelUsageRow] = [], lastUpdated: Date = Date()) {
        self.deepseekBalance = deepseekBalance
        self.minimaxModels = minimaxModels
        self.dailyUsage = dailyUsage
        self.perModelUsage = perModelUsage
        self.lastUpdated = lastUpdated
    }
}

@MainActor
@Observable
public final class UsageViewModel {
    public var state: ViewState = .loading
    public var lastRefresh: Date?
    public var autoRefreshInterval: TimeInterval = 900

    private let authPath: String
    private let dbPath: String
    @ObservationIgnored nonisolated(unsafe) private var refreshTask: Task<Void, Never>?
    private var hasLoaded = false

    public init(authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json", dbPath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db") {
        self.authPath = authPath
        self.dbPath = dbPath
    }

    public func load() async {
        guard AuthReader.readCredentials(authPath: authPath) != nil else {
            state = .onboarding
            return
        }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        await refresh()
        startAutoRefresh()
    }

    public func refresh(session: URLSession = .shared, dbPath: String? = nil) async {
        let effectiveDB = dbPath ?? self.dbPath

        guard let creds = AuthReader.readCredentials(authPath: authPath) else {
            state = .onboarding
            return
        }

        if !hasLoaded {
            state = .loading
        }

        let dsKey = creds.deepseekKey
        let mmKey = creds.minimaxKey

        let dsBalance = try? await DeepSeekAPIService.fetchBalance(apiKey: dsKey, session: session)
        let mmModels = (try? await MiniMaxAPIService.fetchUsage(apiKey: mmKey, session: session)) ?? []

        let usage = DatabaseService.queryUsage(dbPath: effectiveDB)
        let perModelUsage = DatabaseService.queryPerModelUsage(dbPath: effectiveDB)

        if dsBalance == nil, mmModels.isEmpty {
            state = .error("Unable to fetch usage data from any provider")
            return
        }

        let models = mmModels
        let alerts = NotificationManager.checkThresholds(models: models)
        for alert in alerts {
            sendNotification(alert: alert)
        }

        let data = UsageData(
            deepseekBalance: dsBalance,
            minimaxModels: models,
            dailyUsage: usage,
            perModelUsage: perModelUsage,
            lastUpdated: Date()
        )

        hasLoaded = true
        state = .loaded(data)
        lastRefresh = Date()

        let cache = WidgetCache(
            lastUpdated: Date(),
            deepseek: ProviderBalance(balance: dsBalance, currency: "USD"),
            minimax: ProviderBalance(balance: Double(models.reduce(0) { $0 + $1.currentIntervalRemainingCount }), currency: "USD"),
            minimaxUsage: MiniMaxUsage(remainingPrompts: models.reduce(0) { $0 + $1.currentIntervalRemainingCount }, totalPrompts: models.reduce(0) { $0 + $1.currentIntervalTotalCount }),
            dailyUsage: usage
        )
        DataStore.save(cache: cache)
    }

    public func startAutoRefresh() {
        stopAutoRefresh()
        let interval = autoRefreshInterval
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    public func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func sendNotification(alert: ModelAlert) {
        let content = UNMutableNotificationContent()
        content.title = "Usage Alert"
        content.body = alert.level == .critical
            ? "\(alert.modelName) usage critically high (95%+). Check your plan."
            : "\(alert.modelName) usage at 85% or above. Consider upgrading."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "usage-\(alert.modelName)-\(alert.level)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    deinit {
        refreshTask?.cancel()
    }
}
