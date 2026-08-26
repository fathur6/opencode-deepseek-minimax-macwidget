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
    }

    private struct UsageWindow: Decodable {
        let usedPercent: Double?
        let resetAt: Double?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case resetAt = "reset_at"
        }
    }

    /// Fetches the subscription quota using the OAuth token from Codex login.
    /// The weekly/secondary window is preferred because it matches the
    /// weekly usage card; the primary window is a safe fallback.
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
              let window = payload.rateLimit?.secondaryWindow ?? payload.rateLimit?.primaryWindow,
              let usedPercent = window.usedPercent,
              usedPercent.isFinite,
              usedPercent >= 0,
              usedPercent <= 100 else {
            return nil
        }

        let resetDate = window.resetAt.map(Date.init(timeIntervalSince1970:))
        return OpenAIQuota(
            remainingPercent: max(0, min(100, 100 - usedPercent)),
            resetDate: resetDate
        )
    }
}
