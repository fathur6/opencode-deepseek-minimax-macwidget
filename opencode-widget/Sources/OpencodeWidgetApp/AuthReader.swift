import Foundation

struct AuthCredentials {
    let deepseekKey: String
    let minimaxKey: String
}

enum AuthReader {
    nonisolated(unsafe) static var authPath = "\(NSHomeDirectory())/.local/share/opencode/auth.json"

    static func readCredentials() -> AuthCredentials? {
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
