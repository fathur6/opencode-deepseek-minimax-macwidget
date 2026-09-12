import Foundation
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

enum OpenAIQuotaFetcher {
    static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    private struct UsageResponse: Decodable {
        let rateLimit: RateLimit?

        enum CodingKeys: String, CodingKey {
            case rateLimit = "rate_limit"
        }
    }

    private struct RateLimit: Decodable {
        let primaryWindow: UsageWindow?
        let secondaryWindow: UsageWindow?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            primaryWindow = try? values.decode(UsageWindow.self, forKey: .primaryWindow)
            secondaryWindow = try? values.decode(UsageWindow.self, forKey: .secondaryWindow)
        }
    }

    private struct UsageWindow: Decodable {
        let usedPercent: Double?
        let resetAt: Double?
        let duration: Double?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case resetAt = "reset_at"
            case duration = "limit_window_seconds"
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            usedPercent = try? values.decode(Double.self, forKey: .usedPercent)
            resetAt = try? values.decode(Double.self, forKey: .resetAt)
            duration = try? values.decode(Double.self, forKey: .duration)
        }

        var resetDate: Date? {
            // Limit timestamps to Foundation's supported calendar range, not
            // merely finite Doubles (which can represent unusable dates).
            guard let resetAt, resetAt.isFinite, resetAt > 0,
                  resetAt <= Date.distantFuture.timeIntervalSince1970 else { return nil }
            return Date(timeIntervalSince1970: resetAt)
        }
    }

    /// Fetches the subscription quota using the OAuth token from Codex login.
    /// Classifies both windows by duration, never by their position in JSON.
    static func fetch(
        authPath: String = "\(NSHomeDirectory())/.codex/auth.json",
        session: URLSession = .shared,
        endpoint: URL = usageURL
    ) async -> OpenAIQuota? {
        guard let credentials = AuthReader.readOpenAICredentials(authPath: authPath) else {
            return nil
        }
        return await fetch(credentials: credentials, session: session, endpoint: endpoint)
    }

    static func fetch(
        credentials: OpenAIAuthCredentials,
        session: URLSession = .shared,
        endpoint: URL = usageURL
    ) async -> OpenAIQuota? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID = credentials.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        }

        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }

        guard let payload = try? JSONDecoder().decode(UsageResponse.self, from: data),
              let rateLimit = payload.rateLimit else {
            return nil
        }

        var quota = OpenAIQuota()
        for window in [rateLimit.primaryWindow, rateLimit.secondaryWindow].compactMap({ $0 }) {
            guard let usedPercent = window.usedPercent, usedPercent.isFinite,
                  (0...100).contains(usedPercent) else { continue }
            switch window.duration {
            case 18000 where quota.fiveHourRemainingPercent == nil:
                quota.fiveHourRemainingPercent = 100 - usedPercent
                quota.fiveHourResetDate = window.resetDate
            case 604800 where quota.remainingPercent == nil:
                quota.remainingPercent = 100 - usedPercent
                quota.resetDate = window.resetDate
            default: break
            }
        }
        return quota.remainingPercent != nil || quota.fiveHourRemainingPercent != nil ? quota : nil
    }
}
