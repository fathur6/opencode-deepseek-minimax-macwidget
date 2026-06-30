import Foundation
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

public enum NotificationLevel: String, Codable {
    case warning
    case critical
}

public struct ModelAlert: Equatable {
    public let modelName: String
    public let level: NotificationLevel
}

@MainActor
public enum NotificationManager {
    static let warningThreshold: Double = 0.85
    static let criticalThreshold: Double = 0.95

    public static func checkThresholds(models: [MiniMaxModelRemain]) -> [ModelAlert] {
        var alerts: [ModelAlert] = []

        for model in models {
            let usedPct = model.usagePercentage

            if usedPct >= criticalThreshold {
                let alert = ModelAlert(modelName: model.modelName, level: .critical)
                if !hasAlertBeenSent(for: model.modelName, level: .critical) {
                    alerts.append(alert)
                    markAlertSent(for: model.modelName, level: .critical)
                }
            } else if usedPct >= warningThreshold {
                let alert = ModelAlert(modelName: model.modelName, level: .warning)
                if !hasAlertBeenSent(for: model.modelName, level: .warning) {
                    alerts.append(alert)
                    markAlertSent(for: model.modelName, level: .warning)
                }
            }
        }

        return alerts
    }

    private static nonisolated(unsafe) var alertRegistry: [String: Date] = [:]

    private static func hasAlertBeenSent(for modelName: String, level: NotificationLevel) -> Bool {
        let key = "\(modelName)-\(level.rawValue)"
        guard let sentDate = alertRegistry[key] else { return false }
        // Reset after 24 hours
        return Date().timeIntervalSince(sentDate) < 86400
    }

    static func markAlertSent(for modelName: String, level: NotificationLevel) {
        let key = "\(modelName)-\(level.rawValue)"
        alertRegistry[key] = Date()
    }

    static func resetAlerts() {
        alertRegistry = [:]
    }
}
