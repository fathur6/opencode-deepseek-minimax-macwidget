import Foundation

public struct AuthCredentials {
    public let deepseekKey: String
    public let minimaxKey: String

    public init(deepseekKey: String, minimaxKey: String) {
        self.deepseekKey = deepseekKey
        self.minimaxKey = minimaxKey
    }
}

public struct OpenAIAuthCredentials: Sendable {
    public let accessToken: String
    public let accountID: String?

    public init(accessToken: String, accountID: String? = nil) {
        self.accessToken = accessToken
        self.accountID = accountID
    }
}

public enum AuthReader {
    public static func readCredentials(authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json") -> AuthCredentials? {
        let url = URL(fileURLWithPath: authPath)
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let deepseekAuth = json["deepseek"] as? [String: Any],
              let deepseekKey = deepseekAuth["key"] as? String,
              let minimaxAuth = json["minimax"] as? [String: Any],
              let minimaxKey = minimaxAuth["key"] as? String else {
            return nil
        }

        return AuthCredentials(deepseekKey: deepseekKey, minimaxKey: minimaxKey)
    }

    /// Reads the OAuth token produced by `codex login`. The token is returned
    /// only to the caller and is never logged or persisted by this module.
    public static func readOpenAICredentials(authPath: String = "\(NSHomeDirectory())/.codex/auth.json") -> OpenAIAuthCredentials? {
        let url = URL(fileURLWithPath: authPath)
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty else {
            return nil
        }

        return OpenAIAuthCredentials(
            accessToken: accessToken,
            accountID: tokens["account_id"] as? String
        )
    }
}
