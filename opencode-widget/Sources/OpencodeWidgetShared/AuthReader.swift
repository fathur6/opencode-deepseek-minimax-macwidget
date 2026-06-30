import Foundation

public struct AuthCredentials {
    public let deepseekKey: String
    public let minimaxKey: String

    public init(deepseekKey: String, minimaxKey: String) {
        self.deepseekKey = deepseekKey
        self.minimaxKey = minimaxKey
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
}
